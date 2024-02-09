@isTest(seeAllData = false)
public class LinqUtilsTests{
	@IsTest
	static void linqUtils_First_Should_Return_First_Item_Of_Non_Empty_Collection(){
		// Given there is non empty collection
		List<Lead> collection = getCollectionThatContainsMultipleItems();

		// When I get first
		SObject obj = LinqUtils.first(collection);

		// Then I get the first item
		System.assertEquals(collection[0], obj);
	}

	@IsTest
	static void linqUtils_First_Should_Throw_An_Exception_If_Collection_Is_Empty(){
		// Given there is an empty collection
		List<Lead> collection = new List<Lead>();

		// When I get first
		Exception expectedException = null;
		SObject obj = null;
		try{
			obj = LinqUtils.first(collection);
		} catch (Exception dmx){
			expectedException = dmx;
		}

		// Then exception should be thrown
		System.assertNotEquals(null, expectedException);
		System.assertEquals(null, obj);
	}

	@IsTest
	static void linqUtils_Single_Should_Return_First_Item_Of_A_Collection_That_Contains_One_Item(){
		// Given there is a collection that contains one item
		Lead item = new Lead();
		List<Lead> collection = new List<Lead>{item};

		// When I get single item
		SObject obj = LinqUtils.single(collection);

		// Then I get the single item
		System.assertEquals(item, obj);
	}

	@IsTest
	static void linqUtils_Single_Should_Throw_An_Exception_For_An_Empty_Collection(){
		// Given there is an empty collection
		List<Lead> collection = new List<Lead>();

		// When I get single item
		Exception expectedException = null;
		SObject obj = null;
		try{
			obj = LinqUtils.single(collection);
		} catch (Exception dmx){
			expectedException = dmx;
		}

		// Then exception should be thrown
		System.assertNotEquals(null, expectedException);
		System.assertEquals(null, obj);
	}

	@IsTest
	static void linqUtils_Single_Should_Throw_An_Exception_For_A_Collection_That_Contains_Multiple_Items(){
		// Given there is a collection that contains multiple items
		List<Lead> collection = getCollectionThatContainsMultipleItems();

		// When I get single item
		Exception expectedException = null;
		SObject obj = null;
		try{
			obj = LinqUtils.single(collection);
		} catch (Exception dmx){
			expectedException = dmx;
		}

		// Then exception should be thrown
		System.assertNotEquals(null, expectedException);
		System.assertEquals(null, obj);
	}

	@IsTest
	static void linqUtils_SingleOrDefault_Should_Return_First_Item_Of_A_Collection_That_Contains_One_Item(){
		// Given there is a collection that contains one item
		Lead item = new Lead();
		List<Lead> collection = new List<Lead>{item};

		// When I get singleOrDefault item
		SObject obj = LinqUtils.singleOrDefault(collection);

		// Then I get the single item
		System.assertEquals(item, obj);
	}

	@IsTest
	static void linqUtils_SingleOrDefault_Should_Return_Default_For_An_Empty_Collection(){
		// Given there is an empty collection 
		List<Lead> collection = new List<Lead>();

		// When I get singleOrDefault item
		SObject obj = LinqUtils.singleOrDefault(collection);

		// Then I get the default null
		System.assertEquals(null, obj);
	}

	@IsTest
	static void linqUtils_SingleOrDefault_Should_Throw_An_Exception_For_A_Collection_That_Contains_Multiple_Items(){
		// Given there is a collection that contains multiple items
		List<Lead> collection = getCollectionThatContainsMultipleItems();

		// When I get singleOrDefault item
		Exception expectedException = null;
		SObject obj = null;
		try{
			obj = LinqUtils.singleOrDefault(collection);
		} catch (Exception dmx){
			expectedException = dmx;
		}

		// Then exception should be thrown
		System.assertNotEquals(null, expectedException, 'Exceptions should be thrown.');
		System.assertEquals(null, obj);
	}

	static List<Lead> getCollectionThatContainsMultipleItems(){
		return new List<Lead>{new Lead(), new Lead(), new Lead()};
	}
}