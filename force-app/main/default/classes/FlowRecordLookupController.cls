public with sharing class FlowRecordLookupController {
  private static final Integer DEFAULT_MAX_RESULTS = 10;
  private static final Integer HARD_MAX_RESULTS = 50;

  @AuraEnabled(cacheable=true)
  public static List<SObject> search(
    String objectApiName,
    String searchFields,
    String displayFields,
    String searchTerm,
    String filterField,
    String filterValue,
    String accessLevelName,
    Integer maxResults
  ) {
    try {
      Schema.DescribeSObjectResult objDescribe = describeObject(objectApiName);
      Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

      List<String> fieldsToQuery = new List<String>{ 'Id' };
      List<String> searchFieldList = validateFields(
        searchFields,
        fieldMap,
        fieldsToQuery
      );
      validateFields(displayFields, fieldMap, fieldsToQuery);

      if (searchFieldList.isEmpty()) {
        throw new AuraHandledException(
          'At least one valid search field is required.'
        );
      }

      String validatedFilterField;
      if (String.isNotBlank(filterField)) {
        Schema.SObjectField field = fieldMap.get(
          filterField.trim().toLowerCase()
        );
        if (field == null) {
          throw new AuraHandledException(
            'Unknown filter field: ' + filterField
          );
        }
        validatedFilterField = field.getDescribe().getName();
        if (!fieldsToQuery.contains(validatedFilterField)) {
          fieldsToQuery.add(validatedFilterField);
        }
      }

      String orderByField = fieldMap.containsKey('name') ? 'Name' : 'Id';

      List<String> searchConditions = new List<String>();
      for (String searchField : searchFieldList) {
        searchConditions.add(searchField + ' LIKE :likeTerm');
      }

      String query =
        'SELECT ' +
        String.join(fieldsToQuery, ', ') +
        ' FROM ' +
        objDescribe.getName() +
        ' WHERE (' +
        String.join(searchConditions, ' OR ') +
        ')';

      Map<String, Object> binds = new Map<String, Object>();
      binds.put(
        'likeTerm',
        '%' +
          String.escapeSingleQuotes(
            String.isBlank(searchTerm) ? '' : searchTerm
          ) +
          '%'
      );

      if (validatedFilterField != null) {
        query += ' AND ' + validatedFilterField + ' = :filterValueBind';
        binds.put('filterValueBind', filterValue);
      }

      query += ' ORDER BY ' + orderByField + ' LIMIT :limitBind';
      Integer effectiveMax = (maxResults == null ||
        maxResults <= 0)
        ? DEFAULT_MAX_RESULTS
        : Math.min(maxResults, HARD_MAX_RESULTS);
      binds.put('limitBind', effectiveMax);

      System.AccessLevel level = ('System Mode'
          .equalsIgnoreCase(accessLevelName))
        ? System.AccessLevel.SYSTEM_MODE
        : System.AccessLevel.USER_MODE;

      return Database.queryWithBinds(query, binds, level);
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(
        'Unable to search records: ' + e.getMessage()
      );
      ex.setMessage('Unable to search records: ' + e.getMessage());
      throw ex;
    }
  }

  private static Schema.DescribeSObjectResult describeObject(
    String objectApiName
  ) {
    if (String.isBlank(objectApiName)) {
      throw new AuraHandledException('An object API name is required.');
    }
    Schema.SObjectType sObjType = Schema.getGlobalDescribe()
      .get(objectApiName.trim());
    if (sObjType == null) {
      throw new AuraHandledException('Unknown object: ' + objectApiName);
    }
    return sObjType.getDescribe();
  }

  private static List<String> validateFields(
    String csv,
    Map<String, Schema.SObjectField> fieldMap,
    List<String> accumulator
  ) {
    List<String> validated = new List<String>();
    if (String.isBlank(csv)) {
      return validated;
    }
    for (String rawField : csv.split(',')) {
      String fieldName = rawField.trim();
      if (String.isBlank(fieldName)) {
        continue;
      }
      Schema.SObjectField field = fieldMap.get(fieldName.toLowerCase());
      if (field == null) {
        throw new AuraHandledException('Unknown field: ' + fieldName);
      }
      String apiName = field.getDescribe().getName();
      if (!validated.contains(apiName)) {
        validated.add(apiName);
      }
      if (!accumulator.contains(apiName)) {
        accumulator.add(apiName);
      }
    }
    return validated;
  }
}
