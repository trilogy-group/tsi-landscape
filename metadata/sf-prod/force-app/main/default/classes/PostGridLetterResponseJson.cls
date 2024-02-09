// The supplied json has fields with names that are not valid in apex
// and so can only be parsed with explicitly generated code, this option
// was auto selected for you.

public class PostGridLetterResponseJson {

	public String id {get;set;} 
	public String object_Z {get;set;} // in json: object
	public Boolean live {get;set;} 
	public String addressPlacement {get;set;} 
	public Object attachedPDF {get;set;} 
	public Boolean color {get;set;} 
	public String description {get;set;} 
	public Boolean doubleSided {get;set;} 
	public String envelopeType {get;set;} 
	public Boolean express {get;set;} 
	public String extraService {get;set;} 
	public From_Z from_Z {get;set;} // in json: from
	public String html {get;set;} 
	public String mailingClass {get;set;} 
	public MergeVariables mergeVariables {get;set;} 
	public Metadata metadata {get;set;} 
	public Integer perforatedPage {get;set;} 
	public String sendDate {get;set;} 
	public String size {get;set;} 
	public String status {get;set;} 
	public From_Z to {get;set;} 
	public String createdAt {get;set;} 
	public String updatedAt {get;set;} 
    public PostGridLetterResponseJson(){}
	public PostGridLetterResponseJson(JSONParser parser) {
		while (parser.nextToken() != System.JSONToken.END_OBJECT) {
			if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
				String text = parser.getText();
				if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
					if (text == 'id') {
						id = parser.getText();
					} else if (text == 'object') {
						object_Z = parser.getText();
					} else if (text == 'live') {
						live = parser.getBooleanValue();
					} else if (text == 'addressPlacement') {
						addressPlacement = parser.getText();
					} else if (text == 'attachedPDF') {
						attachedPDF = parser.readValueAs(Object.class);
					} else if (text == 'color') {
						color = parser.getBooleanValue();
					} else if (text == 'description') {
						description = parser.getText();
					} else if (text == 'doubleSided') {
						doubleSided = parser.getBooleanValue();
					} else if (text == 'envelopeType') {
						envelopeType = parser.getText();
					} else if (text == 'express') {
						express = parser.getBooleanValue();
					} else if (text == 'extraService') {
						extraService = parser.getText();
					} else if (text == 'from') {
						from_Z = new From_Z(parser);
					} else if (text == 'html') {
						html = parser.getText();
					} else if (text == 'mailingClass') {
						mailingClass = parser.getText();
					} else if (text == 'mergeVariables') {
						mergeVariables = new MergeVariables(parser);
					} else if (text == 'metadata') {
						metadata = new Metadata(parser);
					} else if (text == 'perforatedPage') {
						perforatedPage = parser.getIntegerValue();
					} else if (text == 'sendDate') {
						sendDate = parser.getText();
					} else if (text == 'size') {
						size = parser.getText();
					} else if (text == 'status') {
						status = parser.getText();
					} else if (text == 'to') {
						to = new From_Z(parser);
					} else if (text == 'createdAt') {
						createdAt = parser.getText();
					} else if (text == 'updatedAt') {
						updatedAt = parser.getText();
					} else {
						System.debug(LoggingLevel.WARN, 'JSON2Apex consuming unrecognized property: '+text);
						consumeObject(parser);
					}
				}
			}
		}
	}
	
	public class MergeVariables {
		public String language {get;set;} 

		public MergeVariables(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'language') {
							language = parser.getText();
						} else {
							System.debug(LoggingLevel.WARN, 'MergeVariables consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}
	
	public class From_Z {
		public String id {get;set;} 
		public String object_Z {get;set;} // in json: object
		public String addressLine1 {get;set;} 
		public Object addressLine2 {get;set;} 
		public String addressStatus {get;set;} 
		public String city {get;set;} 
		public String companyName {get;set;} 
		public String country {get;set;} 
		public String countryCode {get;set;} 
		public String firstName {get;set;} 
		public String lastName {get;set;} 
		public String postalOrZip {get;set;} 
		public String provinceOrState {get;set;} 

		public From_Z(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'id') {
							id = parser.getText();
						} else if (text == 'object') {
							object_Z = parser.getText();
						} else if (text == 'addressLine1') {
							addressLine1 = parser.getText();
						} else if (text == 'addressLine2') {
							addressLine2 = parser.readValueAs(Object.class);
						} else if (text == 'addressStatus') {
							addressStatus = parser.getText();
						} else if (text == 'city') {
							city = parser.getText();
						} else if (text == 'companyName') {
							companyName = parser.getText();
						} else if (text == 'country') {
							country = parser.getText();
						} else if (text == 'countryCode') {
							countryCode = parser.getText();
						} else if (text == 'firstName') {
							firstName = parser.getText();
						} else if (text == 'lastName') {
							lastName = parser.getText();
						} else if (text == 'postalOrZip') {
							postalOrZip = parser.getText();
						} else if (text == 'provinceOrState') {
							provinceOrState = parser.getText();
						} else {
							System.debug(LoggingLevel.WARN, 'From_Z consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}
	
	public class Metadata {
		public String company {get;set;} 

		public Metadata(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'company') {
							company = parser.getText();
						} else {
							System.debug(LoggingLevel.WARN, 'Metadata consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}
	
	
	public static PostGridLetterResponseJson parse(String json) {
		System.JSONParser parser = System.JSON.createParser(json);
		return new PostGridLetterResponseJson(parser);
	}
	
	public static void consumeObject(System.JSONParser parser) {
		Integer depth = 0;
		do {
			System.JSONToken curr = parser.getCurrentToken();
			if (curr == System.JSONToken.START_OBJECT || 
				curr == System.JSONToken.START_ARRAY) {
				depth++;
			} else if (curr == System.JSONToken.END_OBJECT ||
				curr == System.JSONToken.END_ARRAY) {
				depth--;
			}
		} while (depth > 0 && parser.nextToken() != null);
	}
}