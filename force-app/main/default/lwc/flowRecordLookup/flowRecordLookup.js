import { LightningElement, api } from "lwc";
import { FlowAttributeChangeEvent } from "lightning/flowSupport";
import search from "@salesforce/apex/FlowRecordLookupController.search";

const DEBOUNCE_DELAY = 300;

export default class FlowRecordLookup extends LightningElement {
  @api label = "Search";
  @api placeholder = "Start typing to search...";
  @api objectApiName;
  @api searchFields;
  @api displayFields;
  @api filterField;
  @api filterValue;
  @api accessLevel = "User Mode";
  @api minSearchLength = 2;
  @api maxResults = 10;
  @api required = false;
  @api allowCreate = false;
  @api createLabelPrefix = "Create new";

  _selectedRecordId;
  _selectedRecordLabel;
  _searchTerm = "";
  _requestNewRecord = false;

  @api
  get selectedRecordId() {
    return this._selectedRecordId;
  }
  set selectedRecordId(value) {
    this._selectedRecordId = value;
  }

  @api
  get selectedRecordLabel() {
    return this._selectedRecordLabel;
  }
  set selectedRecordLabel(value) {
    this._selectedRecordLabel = value;
  }

  @api
  get searchTerm() {
    return this._searchTerm;
  }
  set searchTerm(value) {
    this._searchTerm = value || "";
  }

  @api
  get requestNewRecord() {
    return this._requestNewRecord;
  }
  set requestNewRecord(value) {
    this._requestNewRecord = !!value;
  }

  results = [];
  isSearching = false;
  hasSearched = false;
  errorMessage;

  debounceTimeout;

  get displayFieldList() {
    return (this.displayFields || "")
      .split(",")
      .map((field) => field.trim())
      .filter((field) => field.length > 0);
  }

  get hasResults() {
    return this.results.length > 0;
  }

  get meetsMinSearchLength() {
    return this._searchTerm.length >= Number(this.minSearchLength);
  }

  get showNoResults() {
    return (
      this.hasSearched &&
      !this.isSearching &&
      !this.hasResults &&
      this.meetsMinSearchLength
    );
  }

  get showCreateOption() {
    return (
      this.allowCreate &&
      this.hasSearched &&
      !this.isSearching &&
      this.meetsMinSearchLength
    );
  }

  get showDropdown() {
    return this.hasResults || this.showNoResults || this.showCreateOption;
  }

  get createNewOptionLabel() {
    return `${this.createLabelPrefix} "${this._searchTerm}"`;
  }

  get hasSelection() {
    return !!this._selectedRecordId || this._requestNewRecord;
  }

  get pillLabel() {
    return this._requestNewRecord
      ? this.createNewOptionLabel
      : this._selectedRecordLabel;
  }

  get computedResults() {
    const fields = this.displayFieldList;
    return this.results.map((record) => {
      const title = fields.length > 0 ? record[fields[0]] : record.Id;
      const subtitle = fields
        .slice(1)
        .map((field) => record[field])
        .filter((value) => !!value)
        .join(" · ");
      return {
        id: record.Id,
        title: title || record.Id,
        subtitle,
        key: record.Id
      };
    });
  }

  handleInputChange(event) {
    this._searchTerm = event.target.value;
    this.clearSelection();
    window.clearTimeout(this.debounceTimeout);

    if (this._searchTerm.length < Number(this.minSearchLength)) {
      this.results = [];
      this.hasSearched = false;
      return;
    }

    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.debounceTimeout = window.setTimeout(() => {
      this.runSearch();
    }, DEBOUNCE_DELAY);
  }

  runSearch() {
    this.isSearching = true;
    this.errorMessage = undefined;

    search({
      objectApiName: this.objectApiName,
      searchFields: this.searchFields,
      displayFields: this.displayFields,
      searchTerm: this._searchTerm,
      filterField: this.filterField,
      filterValue: this.filterValue,
      accessLevelName: this.accessLevel,
      maxResults: Number(this.maxResults)
    })
      .then((data) => {
        this.results = data;
        this.hasSearched = true;
      })
      .catch((error) => {
        this.errorMessage =
          (error && error.body && error.body.message) ||
          "Unable to search records.";
        this.results = [];
        this.hasSearched = true;
      })
      .finally(() => {
        this.isSearching = false;
      });
  }

  handleSelect(event) {
    const recordId = event.currentTarget.dataset.id;
    const record = this.computedResults.find(
      (result) => result.id === recordId
    );

    this._selectedRecordId = recordId;
    this._selectedRecordLabel = record ? record.title : recordId;
    this.results = [];
    this.hasSearched = false;

    this.dispatchAttributeChange("selectedRecordId", this._selectedRecordId);
    this.dispatchAttributeChange(
      "selectedRecordLabel",
      this._selectedRecordLabel
    );
    this.dispatchAttributeChange("searchTerm", this._searchTerm);
  }

  handleCreateNew() {
    this._requestNewRecord = true;
    this._selectedRecordId = undefined;
    this._selectedRecordLabel = undefined;
    this.results = [];
    this.hasSearched = false;

    this.dispatchAttributeChange("requestNewRecord", true);
    this.dispatchAttributeChange("selectedRecordId", undefined);
    this.dispatchAttributeChange("selectedRecordLabel", undefined);
    this.dispatchAttributeChange("searchTerm", this._searchTerm);
  }

  handleClearSelection() {
    this._searchTerm = "";
    this.results = [];
    this.hasSearched = false;
    this.clearSelection();
  }

  clearSelection() {
    this._selectedRecordId = undefined;
    this._selectedRecordLabel = undefined;
    this._requestNewRecord = false;
    this.dispatchAttributeChange("selectedRecordId", undefined);
    this.dispatchAttributeChange("selectedRecordLabel", undefined);
    this.dispatchAttributeChange("requestNewRecord", false);
  }

  dispatchAttributeChange(attributeName, value) {
    this.dispatchEvent(new FlowAttributeChangeEvent(attributeName, value));
  }

  @api
  validate() {
    if (this.required && !this._selectedRecordId && !this._requestNewRecord) {
      return {
        isValid: false,
        errorMessage: "Please select a record before continuing."
      };
    }
    return { isValid: true };
  }
}
