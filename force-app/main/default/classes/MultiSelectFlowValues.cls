global class MultiSelectFlowValues {

    @InvocableMethod
    public static List<List<String>> CheckValues(List<String> values) {
        if (values != null && !values.isEmpty() && values[0] != null) {
            String tempStr = values[0];
            List<String> lstnew = tempStr.split('; ');
            List<List<String>> finalLst = new List<List<String>>();
            
            for (String str : lstnew) {
                finalLst.add(new List<String>{str});
            }

            return finalLst;
        } else {
            return null;
        }
    }
}