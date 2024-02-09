global class TaskDispatchBatchV2 implements Database.Batchable<sObject>, Database.Stateful{
	static final Integer MAX_TASKS = 1800;
	static final Integer MAX_PRIORITY = 9;

	static final String ALREADY_EXISTS_TXT = 'already exists';
	static final String MAX_LIMIT_TXT = 'ignored max limit reached';
	static final String TO_CREATE_TXT = 'to create';

	global Database.QueryLocator start(Database.BatchableContext bc){
		initialize();	
		return Database.getQueryLocator('SELECT Id, (SELECT Name, Report_ID__c, Playbook__c ' +
			'FROM Cadence_Task_Configurations__r WHERE Active__c = true), User_Role_ID__c, Task_Timeout__c, Name, ' +
			'Assign_to_Users_in_a_Role__c FROM Task_Dispatcher__c WHERE Active__c = true ORDER BY Priority__c');
	}

	private void initialize(){
		initActiveUsers();
		fillOpportunitiesToFilterOut();
		taskDispatchReportService.configure(0,1440);
		prioritizer = new TaskPrioritizer(MAX_TASKS);
	}

	Set<Id> activeUsersSet; // Active users
	Set<Id> roleUserIds; // Identifiers for all users related to the current dispatcher
	Set<Id> filteredOutOpportunities; // OppIds which should be excluded from all the reports
	DictionaryOfStringSets createTasksDict; // Map for the current dispatcher
	DictionaryOfTasksSets newTasksDict;     // Map for the current dispatcher
	TaskRemovalTracker taskRemovalTracker;
	Set<String> existingTasksSet; // Completed tasks for the current dispatcher (based on the rerise period)
	TaskPrioritizer prioritizer;
	ITaskDispatchReportService taskDispatchReportService = Injector.getInstance().getTaskDispatchReportService();

	public void processTaskDispatcherByName(String taskDispatcherName){
		sObject td = (sObject)LinqUtils.first([SELECT Id, (SELECT Name, Report_ID__c, Playbook__c
													FROM Cadence_Task_Configurations__r WHERE Active__c = true), 
													User_Role_ID__c, Task_Timeout__c, Name, Assign_to_Users_in_a_Role__c
												FROM Task_Dispatcher__c
												WHERE Name = :taskDispatcherName]);
		initialize();
		processTaskDispatcher((Task_Dispatcher__c)td);
		taskDispatchReportService.sendReport();
	}

	// Select opportunities which should be excluded from all the reports
	private void fillOpportunitiesToFilterOut(){
		Task_Dispatcher_Configuration__mdt config = Task_Dispatcher_Configuration__mdt.getInstance('Default');
		//Closed opportunities are ommitted here for performance reasons because they are filtered out at the report level
		String oppFilterOutQuery = 'SELECT Id FROM Opportunity WHERE IsClosed=false' + 
									(string.isBlank(config.Opportunity_FilterOut_Condition__c) ? '' : ' AND ' + config.Opportunity_FilterOut_Condition__c);
		System.debug('Opportunity filter out query: ' + oppFilterOutQuery);
		filteredOutOpportunities = new Map<Id, Opportunity>((List<Opportunity>)Database.query(oppFilterOutQuery)).keySet();
	}

	private void initActiveUsers(){
		activeUsersSet = (new Map<Id, SObject>([SELECT User.Id
		                                        FROM User
		                                        WHERE IsActive = true])).keySet();
	}

	private void processTaskDispatcher(Task_Dispatcher__c taskDispatcher){
		System.debug(LoggingLevel.DEBUG, String.format('Counters: Processing the dispatcher {0}.', 
			new String[]{taskDispatcher.Name}));
		taskDispatchReportService.addTaskDispatch(taskDispatcher.Id, taskDispatcher.Name);
		
		taskRemovalTracker = new TaskRemovalTracker();
		taskRemovalTracker.countTaskBefore();

		List<String> userRoleIds = ((String)taskDispatcher.get('User_Role_ID__c')).split(',');
		roleUserIds = (new Map<Id, SObject>([SELECT User.id
		                                     FROM User
		                                     WHERE UserRole.id IN :userRoleIds])).keySet();
		
		//Almost the same search from above, but the above it's being used to delete tasks, including users
		// that are not active anymore
		List<User> activeUsersInRole = [SELECT User.id FROM User 
										WHERE UserRole.id IN :userRoleIds AND IsActive = true];
		List<Cadence_Task_Configuration__c> taskConfigs = 
			(List<Cadence_Task_Configuration__c>)taskDispatcher.getSObjects('Cadence_Task_Configurations__r');
		Id taskDispatcherId = (Id)taskDispatcher.get('Id');
		if (taskConfigs == null || taskConfigs.size() == 0 || activeUsersInRole.size() == 0){
			 // No backlog items or no active users in role, skip the dispatcher
			return;
		}
		newTasksDict = new DictionaryOfTasksSets();
		createTasksDict = new DictionaryOfStringSets();
		existingTasksSet = getExistingTasks();
		Integer roundRobinIndex = 0;
		for (Cadence_Task_Configuration__c taskConfig : taskConfigs){
			try {
				System.debug(LoggingLevel.DEBUG, String.format('Counters: Processing report id:{0} for dispatcher id:{1}.', 
					new String[]{taskConfig.Report_ID__c, taskDispatcherId}));
				if (taskDispatcher.Assign_to_Users_in_a_Role__c) {
					System.debug('before processBacklogReportRoundRobin');
					roundRobinIndex = processBacklogReportRoundRobin(taskDispatcherId, taskConfig, 
						activeUsersInRole, roundRobinIndex);
					System.debug('after processBacklogReportRoundRobin');
				} else {				
					System.debug('before processBacklogReport');
					processBacklogReport(taskDispatcherId, taskConfig);
					System.debug('after processBacklogReport');
				}
			} catch (Exception ex){
				String message = String.format(
					'Error occured during processing report id: {0} for dispatcher id: {1}\n Message: {2}\n Stack: {3}',
					new String[]{taskConfig.Report_ID__c, taskDispatcherId, ex.getMessage(), ex.getStackTraceString()});
				System.debug(LoggingLevel.ERROR, 'Counters: ERROR!!!' + message);
				ErrorReporting.notifyViaEmail('Task Dispatcher Error: Exception occured', message);
			}
		}

		DictionaryOfStringSets keepTasksDict = new DictionaryOfStringSets();
		DictionaryOfStringSets deleteTasksDict = new DictionaryOfStringSets();
		Map<String, Task> compositeKeyToTaskMap = new Map<String, Task>();
		List<Task> openTasks = [SELECT Id, Priority, OwnerId, WhatId, WhoId, Work_Unit_Backlog_ID__c, Subject
		                        FROM Task
		                        WHERE status = 'Open' AND One_Day_Expire__c = True AND OwnerId IN :roleUserIds
		                        ORDER BY Priority DESC];
		List<Task> oldTasks = [SELECT Id, Priority, OwnerId, WhatId, WhoId, Work_Unit_Backlog_ID__c, Subject
		                       FROM Task
		                       WHERE Status = 'Open' AND One_Day_Expire__c = True AND OwnerId IN :roleUserIds AND createddate != LAST_N_DAYS:1];

		System.debug(LoggingLevel.DEBUG, String.format('Counters: Opened tasks total: {0}, Opened old tasks total: {1}', new String[]{
			String.valueOf(openTasks.size()),
			String.valueOf(oldTasks.size())
		}));
		
		Set<String> oldTasksToDelete = new Set<String>();
		for (Task oldTask : oldTasks){
			Id ownerId = oldTask.OwnerId;
			String taskCompositeKey = getTaskKey(oldTask);
			
			// Check if the task exists for any of the ISRs			
			 if (!createTasksDict.existsAnywhere(taskCompositeKey)){
				oldTasksToDelete.add(taskCompositeKey);
			}
		}

		Integer totalTasksToKeep = 0;
		Integer totalTasksToBeDeleted = 0;
		Map<Id, Task> idToTaskMap = new Map<Id, Task>();

		for (Task openTask : openTasks){
			Id ownerId = openTask.OwnerId;
			String taskCompositeKey = getTaskKey(openTask);
			compositeKeyToTaskMap.put(taskCompositeKey, openTask);
			// adds task to keep list if it is not old. maximum size of keep list is MAX_TASKS/2
			// else adds it to delete list
			if (!oldTasksToDelete.contains(taskCompositeKey) && keepTasksDict.getItemsCountById(ownerId)< MAX_TASKS){
				keepTasksDict.add(ownerId, taskCompositeKey);
				totalTasksToKeep++;
			} else {
				idToTaskMap.put(openTask.Id, openTask);
				deleteTasksDict.add(ownerId, openTask.Id);
				totalTasksToBeDeleted++;
			}
		}

		for (Id ownerId : deleteTasksDict.getKeys()){
			taskRemovalTracker.logDelete(ownerId, deleteTasksDict.getItemsCountById(ownerId), '', String.format('Old tasks and tasks that exceeds {0} count per user', new String[]{
				String.valueOf((MAX_TASKS / 2))}));
		}

		System.debug(LoggingLevel.DEBUG, String.format('Counters: Existing opened task distribution. Opened tasks total: {0}, To keep: {1}, To delete {2}. {1}+{2}={3}', new String[]{
			String.valueOf(openTasks.size()),
			String.valueOf(totalTasksToKeep),
			String.valueOf(totalTasksToBeDeleted),
			String.valueOf(totalTasksToKeep + totalTasksToBeDeleted)
		}));

		List<Task> allTasksList = getAllTasksToAdd(keepTasksDict, deleteTasksDict, taskDispatcher.Id);

		List<Task> tasksToDeleteList = getTasksToDelete(deleteTasksDict, idToTaskMap);

		deleteTasks(tasksToDeleteList);

		insertTasks(allTasksList);
		taskRemovalTracker.logInsert(allTasksList);

		System.debug(LoggingLevel.DEBUG, String.format('Counters: Dispatcher {0} is processed.', new String[]{taskDispatcher.Name}));
		
		taskRemovalTracker.countTaskAfter();
		taskRemovalTracker.dump();
	}

	global void execute(Database.BatchableContext bc, List<sObject> taskDispatchers){
		for (sObject taskDispatcher : taskDispatchers){
			processTaskDispatcher((Task_Dispatcher__c)taskDispatcher);
		}
	}

	global void finish(Database.BatchableContext bc){
		taskDispatchReportService.sendReport();
	}

	// Get a key to find the same task in the past
	static String getTaskKey(Task t){
		String taskCompositeKey = t.Subject + t.WhatId + t.WhoId/* + t.OwnerId*/;
		return taskCompositeKey;
	}

	// Get open tasks
	private Set<String> getExistingTasks(){
		List<Task> existingTasks = [SELECT Id, WhatId, WhoId, Subject, OwnerId
		                            FROM Task
		                            WHERE Status = 'Open'];

		Set<String> existingTasksSet = new Set<String>(); // Construct a set of completed keys
		for (Task ct : existingTasks){
			existingTasksSet.add(getTaskKey(ct));
		}
		System.debug(LoggingLevel.DEBUG, String.format('Counters: Existing tasks count: {0} (keys: {1}).', new String[]{String.valueOf(existingTasks.size()), String.valueOf(existingTasksSet.size())}));

		return existingTasksSet;
	}

	// Run the report and return the results
	private Reports.ReportResults getReportResult(String backlogReportId){
		if (Test.isRunningTest()) {
			Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(backlogReportId).getReportMetadata();

			List<Reports.ReportFilter> filters = new List<Reports.ReportFilter>(); 
			Reports.ReportFilter newFilter = new Reports.ReportFilter();
			newFilter.setColumn('DESCRIPTION');
			newFilter.setOperator('equals');
			newFilter.setValue('ApexTest');
			filters.add(newFilter);
			reportMetadata.setReportFilters(filters);

			return Reports.ReportManager.runReport(backlogReportId,reportMetadata,true); 
		}
		else {
			return Reports.ReportManager.runReport(backlogReportId, true);
		}
	}

	private String getTaskforReportName(Reports.ReportMetadata rm){
		String reportName = rm.getName();
		Integer partToIgnoreIndex = reportName.indexOf('#'); // We skip all characters after '#'
		if (partToIgnoreIndex != -1){
			reportName = reportName.left(partToIgnoreIndex);
		}
		return reportName.trim();
	}

	private Task createTask(ReportRecord record, Id ownerId, String reportName, 
		Id taskDispatcherId, Cadence_Task_Configuration__c taskConfig, ReportValue reportValue) {
		
		if (record.priority == null) {
			reportValue.tasksSkippedNullPriority++;
			return null;
		}

		// Create the tasks only on working days
		Boolean isWorkingDay = todayIsWorkingDay();
		if (!isWorkingDay) {
			reportValue.tasksSkippedNotWorkingDay++;
			return null;
		}
		
		Task newTask = new Task();
		newTask.OwnerId = ownerId;
		newTask.WhatId = record.whatId;
		newTask.WhoId = record.whoId;
		newTask.Type = 'Other';
		if (record.effortTimeMin != null) {
			newTask.Effort_Time_Estimate_Minutes__c = record.effortTimeMin;
		}
		if (record.taskDescription != null) {
			newTask.Description = record.taskDescription;
		}
		newTask.Priority = record.priority;
		newTask.One_Day_Expire__c = True;
		newTask.Subject = reportName;
		newTask.Status = 'Open';
		newTask.ActivityDate = getWorkingDay(System.today()); // Set DueDate for working days only
		newTask.Task_Dispatcher__c = taskDispatcherId;
		newTask.Work_Unit_Backlog_ID__c = taskConfig.Report_ID__c;
		newTask.Work_Unit_Backlog_Name__c = reportName;
		newTask.Description = taskConfig.Playbook__c;
		newTask.Cadence_Task_Configuration__c = taskConfig.Id;
		return newTask;
	}

	private ReportDetails getReportDetails(String backlogReportId) {
		ReportDetails result = new ReportDetails();
		Reports.ReportResults reportResults = getReportResult(backlogReportId);
		result.name = getTaskforReportName(reportResults.getReportMetadata());
		Boolean autoPrioritized = reportResults.getReportMetadata().getName().contains('autoprioritized');
		Reports.Dimension groupingColumn = reportResults.getGroupingsDown();
		List<Reports.GroupingValue> groupingValues = groupingColumn.getGroupings();
		Integer numGroups = groupingValues.size();

		for (Integer i = 0; i < numGroups; i++) {
			List<ReportRecord> records = new List<ReportRecord>();
			Reports.ReportFactWithDetails detailFact = (Reports.ReportFactWithDetails)reportResults.getFactMap().get(i + '!T');
			List<Reports.ReportDetailRow> groupRows = detailFact.getRows();
			for (Reports.ReportDetailRow reportRow : groupRows) {
				records.add(getReportRecord(reportRow, autoPrioritized));
			}
			result.groups.put((Id)groupingValues[i].getValue(), records);
		}
		return result;
	}

	private ReportRecord getReportRecord(Reports.ReportDetailRow row, Boolean autoPrioritized) {
		List<Reports.ReportDataCell> dataCells = row.getDataCells();
		ReportRecord record = new ReportRecord();
		record.whatId = (Id)dataCells[0].getValue();
		record.whoId = (Id)dataCells[1].getValue();
		if (dataCells.size() > 2 && dataCells[2].getValue() != null) {
			record.priority = string.valueOf(dataCells[2].getValue());
		}
		if (autoPrioritized) {
			record.priority = prioritizer.getPriority(record.whatId);
		}
		// With the dynamic task priorities, a task starts with priority 0 and then goes to 10 with time
		record.priority = '0';
		return record;
	}

	// Add tasks to be created by a report given
	private Integer processBacklogReportRoundRobin(Id taskDispatcherId, Cadence_Task_Configuration__c taskConfig,
		List<User> users, Integer actualUserIndex){
		String backlogReportId = taskConfig.Report_ID__c;
		System.debug(LoggingLevel.DEBUG, String.format('processBacklogReportRoundRobin taskDispatcherId:{0}, backlogReportId:{1}.', new String[]{String.valueOf(taskDispatcherId), backlogReportId}));
		ReportDetails report = getReportDetails(backlogReportId);
		taskDispatchReportService.addBacklogReport(taskDispatcherId,backlogReportId,report.name);

		List<ReportRecord> reportRows = new List<ReportRecord>();
		for (List<ReportRecord> records : report.groups.values()) {
			reportRows.addAll(records);
		}

		Map<Integer,List<Task>> taskListByUser = new Map<Integer,List<Task>>();
		for (Integer c = 0; c < users.size(); c++) {
			taskListByUser.put(c,new List<Task>());
		}
		ReportValue reportValue = new ReportValue(taskDispatcherId, backlogReportId,null);
		reportValue.totalTasks = reportRows.size();
		for (ReportRecord row : reportRows){
			if (taskListByUser.get(actualUserIndex).size() >= MAX_TASKS){
				System.debug(LoggingLevel.ERROR, String.format('Counters: Max tasks limit per rep {0} is reached. ' + 
					'{1}-{2}={3} tasks skipped. Task generation stopped for report {4}.', 
					new String[]{String.valueOf(MAX_TASKS), String.valueOf(reportRows.size()), 
						String.valueof(reportValue.tasksToCreate), 
						String.valueOf(reportRows.size()-reportValue.tasksToCreate), 
						report.name}));
				reportValue.maxTasksLimitReached = true;
				break;
			}

			if (filteredOutOpportunities.contains(row.whatId)){
				reportValue.tasksSkippedConfigFilter++;
				continue;
			}
			
			Task newTask = createTask(row, users[actualUserIndex].Id, report.name, taskDispatcherId, taskConfig,
				reportValue);
			if (newTask != null) {
				String newTaskKey = getTaskKey(newTask);
				// Add the task in the list even if we don't actually need to create the task
				// This information will be used to keep existing tasks
				createTasksDict.add(newTask.OwnerId, newTaskKey);
				if (!existingTasksSet.contains(newTaskKey)){
					taskListByUser.get(actualUserIndex).add(newTask);
					reportValue.tasksToCreate++;
					actualUserIndex++;
					if (actualUserIndex == users.size()){
						actualUserIndex = 0;
					}
				} else {
					System.debug('Already have the key: '+newTaskKey);
					reportValue.tasksSkippedAlreadyCreated++;
				}
			}
		}
		
		for (Integer c = 0; c < users.size(); c++) {		
			if (taskListByUser.get(c).size() > 0) {
				newTasksDict.addItems(users[c].Id, taskListByUser.get(c));
				setOwnerRoundRobinBacklogValuesToReport(
					new ReportValue(taskDispatcherId, backlogReportId, users[c].Id), taskListByUser.get(c).size());
			}
		}

		setRoundRobinBacklogValuesToReport(reportValue);

		System.debug(LoggingLevel.DEBUG, String.format('Counters: Report "{0}" processed. Total report rows: {1}, ' + 
			'Tasks created: {2}, Skipped rows total: {3} (by config filter: {4}, task already exist: {5}).', 
			new String[]{report.name, String.valueOf(reportRows.size()), String.valueOf(reportValue.tasksToCreate), 
				String.valueOf(reportValue.tasksSkippedConfigFilter + reportValue.tasksSkippedAlreadyCreated), 
				String.valueOf(reportValue.tasksSkippedConfigFilter), 
				String.valueOf(reportValue.tasksSkippedAlreadyCreated)}));
		
		return actualUserIndex;
	}

	// Add tasks to be created by a report given
	private void processBacklogReport(Id taskDispatcherId, Cadence_Task_Configuration__c taskConfig) {
		String backlogReportId = taskConfig.Report_ID__c;
		ReportDetails report = getReportDetails(backlogReportId);
		taskDispatchReportService.addBacklogReport(taskDispatcherId,backlogReportId,report.name);
		System.debug(LoggingLevel.DEBUG, String.format('processBacklogReport taskDispatcherId:{0}, backlogReportId:{1}.', new String[]{String.valueOf(taskDispatcherId), backlogReportId}));

		Integer totalReportRows = 0;
		Integer totalTasksCreated = 0;
		Integer totalTasksSkippedByConfigFilter = 0;
		Integer totalTasksSkippedByOwnerIsNotActiveOrWrongRole = 0;
		Integer totalTasksSkippedIsAlreadyCreated = 0;

		for (Id ownerId : report.groups.keySet()) {
			List<Task> newTaskList = new List<Task>();

			List<ReportRecord> records = report.groups.get(ownerId);
			totalReportRows = totalReportRows + records.size();

			taskRemovalTracker.logReport(ownerId, records.size(), report.name);
			ReportValue reportValue = new ReportValue(taskDispatcherId, backlogReportId, ownerId);
			reportValue.totalTasks = records.size();

			Integer ownerTotalTasks = 0;
			if (roleUserIds.contains(ownerId) && activeUsersSet.contains(ownerId)){
				for (ReportRecord row : records){
					System.debug(LoggingLevel.DEBUG, String.format('processBacklogReport processing row whatId:{0}, whoId:{1}, priority:{2}, effortTimeMin:{3}, taskDescription:{4}.', new String[]{String.valueOf(row.whatId), String.valueOf(row.whoId), row.priority, String.valueOf(row.effortTimeMin), row.taskDescription}));

					if (ownerTotalTasks >= MAX_TASKS){
						System.debug(LoggingLevel.ERROR, String.format('Counters: Max tasks limit per rep {0} is reached. {1}-{0}={2} tasks skipped. Task generation stopped for report {3}, ownerId {4}.', 
							new String[]{String.valueOf(MAX_TASKS), String.valueOf(records.size()), 
								String.valueOf(records.size()-MAX_TASKS), report.name, String.valueOf(ownerId)}));
						taskRemovalTracker.logRemoval(ownerId, records.size()-MAX_TASKS, '', 'MAX_TASKS limit');
						reportValue.maxTasksLimitReached = true;
						break;
					}

					if (filteredOutOpportunities.contains(row.whatId)){
						totalTasksSkippedByConfigFilter++;
						reportValue.tasksSkippedConfigFilter++;
						taskRemovalTracker.logRemoval(ownerId, 1, '', 'Config filter');
						continue;
					}

					Task newTask = createTask(row, ownerId, report.name, taskDispatcherId, taskConfig, 
						reportValue);
					if (newTask != null){
						String newTaskKey = getTaskKey(newTask);
						// Add the task in the list even if we don't actually need to create the task
				        // This information will be used to keep existing tasks
						createTasksDict.add(ownerId, newTaskKey);						
						if (!existingTasksSet.contains(newTaskKey)){
							newTaskList.add(newTask);
							totalTasksCreated++;
							reportValue.tasksToCreate++;
						} else {
							taskRemovalTracker.logRemoval(ownerId, 1, newTaskKey, 'Exists already or priority null or the weekend now');
							totalTasksSkippedIsAlreadyCreated++;
							reportValue.tasksSkippedAlreadyCreated++;
						}
						ownerTotalTasks++;
					}
				}
				if (newTaskList.size() > 0) {
					newTasksDict.addItems(ownerId, newTaskList);
				}
			} else {
				totalTasksSkippedByOwnerIsNotActiveOrWrongRole = totalTasksSkippedByOwnerIsNotActiveOrWrongRole + 
					records.size();
				taskRemovalTracker.logRemoval(ownerId, records.size(), '', 'Owner Is Not Active Or Wrong Role');
				reportValue.assigneeInactiveOrWrongRole = true;
			}
			setOwnerBacklogValuesToReport(reportValue);
		}

		System.debug(LoggingLevel.DEBUG, String.format('Counters: Report "{0}" processed. Total report rows: {1},' +
			' Tasks created: {2}, Skipped rows total: {3} (by config filter: {4}, inactive owners or not matching ' +
			'role: {5}, task already exist: {6}).', 
			new String[]{report.name, String.valueOf(totalReportRows), String.valueOf(totalTasksCreated), 
				String.valueOf(totalTasksSkippedByConfigFilter + totalTasksSkippedByOwnerIsNotActiveOrWrongRole + totalTasksSkippedIsAlreadyCreated),
				String.valueOf(totalTasksSkippedByConfigFilter), String.valueOf(totalTasksSkippedByOwnerIsNotActiveOrWrongRole), String.valueOf(totalTasksSkippedIsAlreadyCreated)}));
	}

	// Get next Monday if the given date is Saturday or Sunday
	public static Date getWorkingDay(Date activityDate){
		Integer weekendsOffset = Math.mod(date.newinstance(1900, 1, 6).daysBetween(activityDate), 7);
		if (weekendsOffset == 0 || weekendsOffset == 1){
			 // Saturday or Sunday
			activityDate += 2 - weekendsOffset;
		}
		return activityDate;
	}

	public static Boolean todayIsWorkingDay() {
		return getWorkingDay(System.today()) == System.today();
	}

	private List<Task> getAllTasksToAdd(DictionaryOfStringSets keepTasksDict, DictionaryOfStringSets deleteTasksDict, 
		Id taskDispatcherId){
		Integer totalTasks = 0;
		Integer totalTasksSkipped = 0;
		List<Task> allTasksList = new List<Task>();
		for (Id ownerId : newTasksDict.getKeys()){
			Set<Task> unsortedTasksOfOwner = newTasksDict.getItemsById(ownerId);
			totalTasks = totalTasks + unsortedTasksOfOwner.size();
			List<TaskWrapper> taskWrappersOfOwner = new List<TaskWrapper>();
			for (Task t : unsortedTasksOfOwner){
				taskWrappersOfOwner.add(new TaskWrapper(t));
			}
			taskWrappersOfOwner.sort(); // sort by priority
			
			List<Task> tasksToAddToList = new List<Task>();
			Set<String> alreadyAddedTasks = new Set<String>();
			Integer numTasksToAdd = MAX_TASKS;
			Integer keepCount = 0;
			String messageTracker;
			if (keepTasksDict.keyExists(ownerId)){
				keepCount = keepTasksDict.getItemsCountById(ownerId);
				numTasksToAdd = numTasksToAdd - keepCount;
				System.debug(LoggingLevel.DEBUG, String.format('Counters: Maximum Tasks to add for owner {1} is set' +
					' to {2}. Its less than MAX_TASKS {3} because this owner has {0} opened tasks already.', 
					new String[]{String.valueOf(keepCount), String.valueOf(ownerId), String.valueOf(numTasksToAdd), 
						String.valueOf(MAX_TASKS)}));
				messageTracker = String.format('Because this owner has {0} opened tasks already', 
					new String[]{String.valueOf(keepCount)});
			} else {
				System.debug(LoggingLevel.DEBUG, String.format('Counters: Maximum Tasks to add for owner {0} is set to {1}.',
					new String[]{String.valueOf(ownerId), String.valueOf(numTasksToAdd)}));
				messageTracker = String.format('Because the limit of tasks per owner {0}', 
					new String[]{String.valueOf(numTasksToAdd)});
			}
			if (taskWrappersOfOwner.size() > numTasksToAdd) {
				totalTasksSkipped+= taskWrappersOfOwner.size()-numTasksToAdd;
				taskRemovalTracker.logRemoval(ownerId, taskWrappersOfOwner.size()-numTasksToAdd, '', messageTracker);
			}

			Integer alreadyExistsCount = 0;
			for (Integer i = 0; i < numTasksToAdd; i++){
				if (i > taskWrappersOfOwner.size()-1){
					break;
				}
				Task originalTask = taskWrappersOfOwner[i].tsk;

				Id taskOwnerId = originalTask.OwnerId;
				String taskCompositeKey = getTaskKey(originalTask);
				
				if (!keepTasksDict.itemExists(taskOwnerId, taskCompositeKey)){
					addTaskIfItHasntBeenAdded(originalTask, deleteTasksDict, taskOwnerId, taskCompositeKey, alreadyAddedTasks, tasksToAddToList);
				} else{
					alreadyExistsCount++;
					totalTasksSkipped++;
					numTasksToAdd = numTasksToAdd + 1;
					taskRemovalTracker.logRemoval(taskOwnerId, 1, taskCompositeKey, 'Task already exists');
				}
			}
			allTasksList.addAll(tasksToAddToList);

			setOwnerProcessingValuesToReport(new ReportValue(taskDispatcherId, ownerId), keepCount, 
				tasksToAddToList.size(), taskWrappersOfOwner.size()-(tasksToAddToList.size() + alreadyExistsCount));
		}
		System.debug(LoggingLevel.DEBUG, String.format('Counters: Total tasks before getAllTasksToAdd {0}, ' +
			'after {1}. Skipped: {2}.', new String[]{String.valueOf(totalTasks), String.valueOf(allTasksList.size()),
			String.valueOf(totalTasksSkipped)}));
		return allTasksList;
	}

	private List<Task> getTasksToDelete(DictionaryOfStringSets deleteTasksMap, Map<Id, Task> idToTaskMap){
		List<Task> tasksToDeleteList = new List<Task>();
		for (Id key : deleteTasksMap.getKeys()){
			for (String taskId : deleteTasksMap.getItemsById(key)){
				Task taskToDelete = idToTaskMap.get(taskId);
				if (taskToDelete == null)
				{
					System.debug(LoggingLevel.ERROR, String.format(
						'Counters: Cant get the task by id {0} in getTasksToDelete.', new String[]{taskId}));
				}
				tasksToDeleteList.add(taskToDelete);
			}
		}
		return tasksToDeleteList;
	}

	private void deleteTasks(List<Task> tasksToDeleteList){
		if (tasksToDeleteList.size() > 0){
			delete tasksToDeleteList;
			System.debug(LoggingLevel.DEBUG, String.format('Counters: Total tasks deleted {0}.', new String[]{String.valueOf(tasksToDeleteList.size())}));
			Database.emptyRecycleBin(tasksToDeleteList);
		}
	}

	private void insertTasks(List<Task> allTasksList){
		insert allTasksList;
		System.debug(LoggingLevel.DEBUG, String.format('Counters: Total tasks inserted {0}.', new String[]{String.valueOf(allTasksList.size())}));
	}
	
	private void addTaskIfItHasntBeenAdded(Task originalTask, DictionaryOfStringSets deleteTasksDict, Id taskOwnerId, String taskCompositeKey, Set<String> alreadyAddedTasks, List<Task> tasksToAddToList){
		if (deleteTasksDict.remove(taskOwnerId,originalTask.Id)){
			taskRemovalTracker.logRemoval(taskOwnerId, 1, taskCompositeKey, 'Task removed from to delete list');
		} else{
			// We haven't added the same task yet 
			if (!alreadyAddedTasks.contains(taskCompositeKey)) {
				tasksToAddToList.add(originalTask);
				alreadyAddedTasks.add(taskCompositeKey);
			} else {
				taskRemovalTracker.logRemoval(taskOwnerId, 1, taskCompositeKey, 'Task already added');
			}
		}
	}

	private void setOwnerProcessingValuesToReport(ReportValue baseValue, Integer existentTasks, 
		Integer createdTasks, Integer ignoredTasksMaxLimitReached) {
		Id tdId = baseValue.taskDispatcherId;
		Id ownerId = baseValue.ownerId;

		taskDispatchReportService.addAssignee(tdId, ownerId);
		taskDispatchReportService.addValueToAssignee(tdId, ownerId, ALREADY_EXISTS_TXT, existentTasks);
		taskDispatchReportService.addValueToAssignee(tdId, ownerId, 'created', createdTasks);
		taskDispatchReportService.addValueToAssignee(tdId, ownerId, MAX_LIMIT_TXT, 
			ignoredTasksMaxLimitReached);
	}

	private void setOwnerBacklogValuesToReport(ReportValue reportValue) {
		Id tdId = reportValue.taskDispatcherId;
		Id brId = reportValue.backlogReportId;
		Id ownerId = reportValue.ownerId;

		taskDispatchReportService.addAssignee(tdId, brId, ownerId);
		taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, 'total', reportValue.totalTasks);
		if (reportValue.assigneeInactiveOrWrongRole) {
			taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, TO_CREATE_TXT, 0);
			taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, 
				'ignored assignee inactive or in wrong role', reportValue.totalTasks);
		} else {
			taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, TO_CREATE_TXT, 
				reportValue.tasksToCreate);
			if (reportValue.tasksSkippedAlreadyCreated > 0) {
				taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, 
					ALREADY_EXISTS_TXT, reportValue.tasksSkippedAlreadyCreated);
			}
			if (reportValue.tasksSkippedConfigFilter > 0) {
				taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, 
					'ignored by config filter', reportValue.tasksSkippedConfigFilter);
			}
			if (reportValue.tasksSkippedNullPriority > 0) {
				taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, 
					'ignored tasks without priority', reportValue.tasksSkippedNullPriority);
			}
			if (reportValue.tasksSkippedNotWorkingDay > 0) {
				taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, 
					'ignored not working day', reportValue.tasksSkippedNotWorkingDay);
			}
			if (reportValue.maxTasksLimitReached) {
				taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, MAX_LIMIT_TXT, 
					reportValue.getIgnoredMaxLimitReached());
			}
		}
	}

	private void setRoundRobinBacklogValuesToReport(ReportValue reportValue) {
		Id tdId = reportValue.taskDispatcherId;
		Id brId = reportValue.backlogReportId;

		taskDispatchReportService.addValueToBacklogReport(tdId, brId, 'total', reportValue.totalTasks);
		taskDispatchReportService.addValueToBacklogReport(tdId, brId, TO_CREATE_TXT, reportValue.tasksToCreate);
		if (reportValue.tasksSkippedAlreadyCreated > 0) {
			taskDispatchReportService.addValueToBacklogReport(tdId, brId, ALREADY_EXISTS_TXT, 
			reportValue.tasksSkippedAlreadyCreated);
		}
		if (reportValue.tasksSkippedConfigFilter > 0) {
			taskDispatchReportService.addValueToBacklogReport(tdId, brId, 'ignored by config filter', 
			reportValue.tasksSkippedConfigFilter);
		}
		if (reportValue.tasksSkippedNullPriority > 0) {
			taskDispatchReportService.addValueToBacklogReport(tdId, brId, 'ignored tasks without priority', 
				reportValue.tasksSkippedNullPriority);
		}
		if (reportValue.tasksSkippedNotWorkingDay > 0) {
			taskDispatchReportService.addValueToBacklogReport(tdId, brId, 'ignored not working day', 
				reportValue.tasksSkippedNotWorkingDay);
		}
		if (reportValue.maxTasksLimitReached) {
			taskDispatchReportService.addValueToBacklogReport(tdId, brId, MAX_LIMIT_TXT, 
				reportValue.getIgnoredMaxLimitReached());
		}
	}

	private void setOwnerRoundRobinBacklogValuesToReport(ReportValue baseValue, Integer tasksToCreate) {
		Id tdId = baseValue.taskDispatcherId;
		Id brId = baseValue.backlogReportId;
		Id ownerId = baseValue.ownerId;

		taskDispatchReportService.addAssignee(tdId, brId, ownerId);
		taskDispatchReportService.addValueToAssignee(tdId, brId, ownerId, TO_CREATE_TXT, tasksToCreate);
	}

	class ReportValue {
		public Id taskDispatcherId;
		public Id backlogReportId;
		public Id ownerId;

		public Integer totalTasks = 0;
		public Boolean assigneeInactiveOrWrongRole = false;
		public Integer tasksToCreate = 0;
		public Integer tasksSkippedAlreadyCreated = 0;
		public Integer tasksSkippedConfigFilter = 0; 
		public Boolean maxTasksLimitReached = false;
		public Integer tasksSkippedNullPriority = 0;
		public Integer tasksSkippedNotWorkingDay = 0;

		public ReportValue(Id taskDispatcherId, Id ownerId) {
			this(taskDispatcherId, null, ownerId);
		}

		public ReportValue(Id taskDispatcherId, Id backlogReportId, Id ownerId) {
			this.taskDispatcherId = taskDispatcherId;
			this.backlogReportId = backlogReportId;
			this.ownerId = ownerId;
		}
		
		public Integer getTotalSkipped() {
			return this.tasksSkippedAlreadyCreated + this.tasksSkippedConfigFilter + this.tasksSkippedNullPriority +
				this.tasksSkippedNotWorkingDay;
		}

		public Integer getIgnoredMaxLimitReached() {
			return this.totalTasks - (this.tasksToCreate + this.getTotalSkipped());
		}
	}

	with sharing class TaskRemovalTracker {
		
		List<RemovalTrackerRecord> recs = new List<RemovalTrackerRecord>();

		public void logReport(Id ownerId, Integer count, String reportName){
			recs.add(new RemovalTrackerRecord(ownerId, 1, count, '', 'Report: ' + reportName));
		}

		public void logRemoval(Id ownerId, Integer count, String taskCompositeKey, String reason){
			recs.add(new RemovalTrackerRecord(ownerId, 2, count, taskCompositeKey, reason));
		}

		public void logInsert(List<Task> tasks){
			DictionaryOfTasksSets tasksDict = new DictionaryOfTasksSets();
			for (Task task : tasks){
				tasksDict.add(task.OwnerId, task);
			}

			for (Id ownerId : tasksDict.getKeys()){
				recs.add(new RemovalTrackerRecord(ownerId, 3, tasksDict.getItemsCountById(ownerId), '', ''));
			}
		}

		public void logDelete(Id ownerId, Integer count, String taskCompositeKey, String reason){
			recs.add(new RemovalTrackerRecord(ownerId, 4, count, taskCompositeKey, reason));
		}

		public void logState(Integer type, Id ownerId, Integer count, String reason){
			recs.add(new RemovalTrackerRecord(ownerId, type, count, '', reason));
		}

		public void dump() {
			Map<Id, Set<RemovalTrackerRecord>> groupedRecs = groupByOwnerAggregateByReason(recs);

			Set<Id> userIds = groupedRecs.keySet();
			Map<Id, User> usersMap = (new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :userIds]));
			System.debug(LoggingLevel.DEBUG, 'Counters: --------------- Tasks generation dump ---------------');
		
			for (Id ownerId : usersMap.keySet()){
				for (RemovalTrackerRecord rec : groupedRecs.get(ownerId)){
					System.debug(LoggingLevel.DEBUG, String.format('Counters: user: {0}. {1} {2} {3}{4}.', new String[]{
						usersMap.get(ownerId).Name,
						logTypeToLabel(rec.Type),
						String.valueOf(rec.Count),
						rec.Reason,
						rec.TaskCompositeKey != null && rec.TaskCompositeKey != '' ? ' Task key: ' + rec.TaskCompositeKey : ''
					}));
				}
			}

			System.debug(LoggingLevel.DEBUG, 'Counters: ----------- End of tasks generation dump ------------');
		}

		String logTypeToLabel(Integer type){
			return type == 0 ? 'Before' : type == 1 ? 'In Report' : type == 2 ? 'Removed' : type == 3 ? 'Inserted' : type == 4 ? 'Will be deleted' : 'After';
		}

		Integer aggregateCount(Set<RemovalTrackerRecord> recs){
			Integer count = 0;
			
			for (RemovalTrackerRecord rec : recs){
				count = count + rec.Count;
			}
			return count;
		}

		Map<Id, Set<RemovalTrackerRecord>> groupByOwnerAggregateByReason(List<RemovalTrackerRecord> recs){
			Map<Id, Map<Integer, Map<String, Set<RemovalTrackerRecord>>>> dictByReason = new Map<Id, Map<Integer, Map<String, Set<RemovalTrackerRecord>>>>();

			// group recs by reasons
			for (RemovalTrackerRecord rec : recs){
				if (dictByReason.get(rec.OwnerId) == null){
					dictByReason.put(rec.OwnerId, new Map<Integer, Map<String, Set<RemovalTrackerRecord>>>());
				}

				if (dictByReason.get(rec.OwnerId).get(rec.Type) == null){
					dictByReason.get(rec.OwnerId).put(rec.Type, new Map<String, Set<RemovalTrackerRecord>>());
				}

				if (dictByReason.get(rec.OwnerId).get(rec.Type).get(rec.Reason) == null){
					dictByReason.get(rec.OwnerId).get(rec.Type).put(rec.Reason, new Set<RemovalTrackerRecord>());
				}
				
				dictByReason.get(rec.OwnerId).get(rec.Type).get(rec.Reason).add(rec);
			}

			Map<Id, Set<RemovalTrackerRecord>> res = new Map<Id, Set<RemovalTrackerRecord>>();

			for (Id ownerId : dictByReason.keySet()){
				for (Integer type : dictByReason.get(ownerId).keySet()){
					for (String reason : dictByReason.get(ownerId).get(type).keySet()){
						if (res.get(ownerId) == null) {
							res.put(ownerId, new Set<RemovalTrackerRecord>());
						}
						res.get(ownerId).add(new RemovalTrackerRecord(ownerId, type, aggregateCount(dictByReason.get(ownerId).get(type).get(reason)), '', reason));
					}
				}
			}

			return res;
		}

		public void countTaskBefore(){
			countExistingTasks(0, 'Task count before');
		}
		public void countTaskAfter(){
			countExistingTasks(5, 'Task count after');
		}
		void countExistingTasks(Integer type, String reason){
			List<SObject> recs = [SELECT Owner.Id Id, Count(Id) Cnt FROM Task WHERE Status = 'Open' and One_Day_Expire__c = True Group by Owner.Id];
			for (SObject rec : recs) {
				logState(type, (Id)rec.get('Id'), (Integer)rec.get('Cnt'), reason);
			}
		}
	}

	global class RemovalTrackerRecord implements Comparable {
		Id OwnerId;
		Integer Type; // 1 = in the report, 2 = removed, 3 = inserted;
		Integer Count;
		String TaskCompositeKey;
		String Reason;

		RemovalTrackerRecord(Id ownerId, Integer type, Integer count, String taskCompositeKey, String reason) {
			this.OwnerId = ownerId;
			this.Type = type;
			this.Count = count;
			this.TaskCompositeKey = taskCompositeKey;
			this.Reason = reason;
		}

		global Integer compareTo(Object compareTo) {
			RemovalTrackerRecord compareToRec = (RemovalTrackerRecord)compareTo;
			Integer returnValue = 0;
			if (compareToRec.Type > Type) {
				returnValue = 1;
			} else if (compareToRec.Type < Type) {
				returnValue = -1;
			}
			return returnValue;
		}
	}

	class ReportDetails {
		String name;
		Map<Id, List<ReportRecord>> groups = new Map<Id, List<ReportRecord>>();
	}

	class ReportRecord {
		Id whatId;
		Id whoId;
		String priority = null;
		Decimal effortTimeMin = null;
		String taskDescription = null;
	}

	class DictionaryOfStringSets {
		Map<Id, Set<String>> dictionaryOfSets = new Map<Id, Set<String>>();

		public void add(Id id, String item){
			if (dictionaryOfSets.get(id) == null){
				Set<String> newSet = new Set<String>();
				newSet.add(item);
				dictionaryOfSets.put(id, newSet);
			} else if (dictionaryOfSets.get(id) != null){
				dictionaryOfSets.get(id).add(item);
			}
		}

		public Boolean remove(Id id, String item){
			if (itemExists(id, item)){
				dictionaryOfSets.get(id).remove(item);
				return true;
			}
			return false;
		}

		public Boolean keyExists(Id id) {
			return dictionaryOfSets.get(id) != null;
		}

		public Boolean itemExists(Id id, String item) {
			return keyExists(id) && getItemsById(id).contains(item);
		}

		// Search the item in any of the sets
		public Boolean existsAnywhere(String item){
			for (Id id : getKeys()){
				if(getItemsById(id).contains(item)){
					return true;
				}
			}
			return false;
		}

		public Set<String> getItemsById(Id id) {
			return dictionaryOfSets.get(id);
		}

		public Set<Id> getKeys() {
			return dictionaryOfSets.keySet();
		}

		public Integer getItemsCountById(Id id) {
			Set<String> itemsSet =  dictionaryOfSets.get(id);
			if (itemsSet == null) {
				return 0;
			} else {
				return itemsSet.size();
			}
		}
	}

	class DictionaryOfTasksSets {
		Map<Id, Set<Task>> dictionaryOfSets = new Map<Id, Set<Task>>();

		public void add(Id id, Task item){
			if (dictionaryOfSets.get(id) == null){
				Set<Task> newSet = new Set<Task>();
				newSet.add(item);
				dictionaryOfSets.put(id, newSet);
			} else if (dictionaryOfSets.get(id) != null){
				dictionaryOfSets.get(id).add(item);
			}
		}

		public void addItems(Id id, List<Task> items){
			if (dictionaryOfSets.get(id) == null){
				Set<Task> newSet = new Set<Task>();
				newSet.addAll(items);
				dictionaryOfSets.put(id, newSet);
			} else if (dictionaryOfSets.get(id) != null){
				dictionaryOfSets.get(id).addAll(items);
			}
		}

		public Boolean remove(Id id, Task item){
			if (itemExists(id, item)){
				dictionaryOfSets.get(id).remove(item);
				return true;
			}
			return false;
		}

		public Boolean keyExists(Id id) {
			return dictionaryOfSets.get(id) != null;
		}

		public Boolean itemExists(Id id, Task item) {
			return keyExists(id) && getItemsById(id).contains(item);
		}

		// Search the task in any of the sets
		public Boolean existsAnywhere(Task item){
			for (Id id : getKeys()){
				if(getItemsById(id).contains(item)){
					return true;
				}
			}
			return false;
		}

		public Set<Task> getItemsById(Id id) {
			return dictionaryOfSets.get(id);
		}

		public Set<Id> getKeys() {
			return dictionaryOfSets.keySet();
		}

		public Integer getItemsCountById(Id id) {
			Set<Task> itemsSet =  dictionaryOfSets.get(id);
			if (itemsSet == null) {
				return 0;
			} else {
				return itemsSet.size();
			}
		}
	}
}