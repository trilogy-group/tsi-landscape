public with sharing class LinqUtils{
	public static sObject first(List<sObject> collection){
		if (collection.size() == 0){
			throw new InvalidOperationException('Collection is empty.');
		}
		return collection[0];
	}

	public static sObject singleOrDefault(List<SObject> collection){
		if (collection.size() > 1){
			throw new InvalidOperationException('Collection contains more than one element.');
		}
		if (collection.size() == 1){
			return collection[0];
		}
		return null;
	}

	public static sObject single(List<SObject> collection){
		if (collection.size() != 1){
			throw new InvalidOperationException('Collection does\'n contain exactly one element.');
		}
		return collection[0];
	}
}