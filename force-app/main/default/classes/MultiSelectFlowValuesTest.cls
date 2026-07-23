@isTest
private class MultiSelectFlowValuesTest {

    @isTest
    static void testCheckValues() {

        // Test Case 1: Valid input
        List<String> inputValues1 = new List<String>{'value1; value2; value3'};
        List<List<String>> expectedResult1 = new List<List<String>>{
            new List<String>{'value1'},
            new List<String>{'value2'},
            new List<String>{'value3'}
        };

        List<List<String>> actualResult1 = MultiSelectFlowValues.CheckValues(inputValues1);
        System.assertEquals(expectedResult1, actualResult1, 'Test Case 1 Failed');

        // Test Case 2: Empty input
        List<String> inputValues2 = new List<String>{};
        List<List<String>> expectedResult2 = null;

        List<List<String>> actualResult2 = MultiSelectFlowValues.CheckValues(inputValues2);
        System.assertEquals(expectedResult2, actualResult2, 'Test Case 2 Failed');

        // Test Case 3: Null input
        List<String> inputValues3 = null;
        List<List<String>> expectedResult3 = null;

        List<List<String>> actualResult3 = MultiSelectFlowValues.CheckValues(inputValues3);
        System.assertEquals(expectedResult3, actualResult3, 'Test Case 3 Failed');
    }
}