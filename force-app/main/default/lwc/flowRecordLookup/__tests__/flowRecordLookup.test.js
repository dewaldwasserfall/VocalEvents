import { createElement } from "lwc";
import FlowRecordLookup from "c/flowRecordLookup";
import search from "@salesforce/apex/FlowRecordLookupController.search";

jest.mock(
  "@salesforce/apex/FlowRecordLookupController.search",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function createComponent(overrides = {}) {
  const element = createElement("c-flow-record-lookup", {
    is: FlowRecordLookup
  });
  element.objectApiName = "Venue__c";
  element.searchFields = "Name,Town__c";
  element.displayFields = "Name,Town__c";
  element.minSearchLength = 2;
  Object.assign(element, overrides);
  document.body.appendChild(element);
  return element;
}

describe("c-flow-record-lookup", () => {
  afterEach(() => {
    jest.clearAllMocks();
    jest.useRealTimers();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders a text input and no results before searching", () => {
    const element = createComponent();
    const input = element.shadowRoot.querySelector("input");
    expect(input).not.toBeNull();
    expect(element.shadowRoot.querySelector('[role="listbox"]')).toBeNull();
  });

  it("does not call Apex when the typed term is shorter than minSearchLength", () => {
    jest.useFakeTimers();
    const element = createComponent();
    const input = element.shadowRoot.querySelector("input");

    input.value = "A";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(500);

    expect(search).not.toHaveBeenCalled();
  });

  it("debounces and calls Apex with the configured parameters once the minimum length is met", async () => {
    jest.useFakeTimers();
    search.mockResolvedValue([]);
    const element = createComponent({
      filterField: "Town__c",
      filterValue: "Pretoria",
      accessLevel: "System Mode"
    });
    const input = element.shadowRoot.querySelector("input");

    input.value = "City";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(300);
    await flushPromises();

    expect(search).toHaveBeenCalledTimes(1);
    expect(search).toHaveBeenCalledWith({
      objectApiName: "Venue__c",
      searchFields: "Name,Town__c",
      displayFields: "Name,Town__c",
      searchTerm: "City",
      filterField: "Town__c",
      filterValue: "Pretoria",
      accessLevelName: "System Mode",
      maxResults: 10
    });
  });

  it("renders returned records in the results list", async () => {
    jest.useFakeTimers();
    search.mockResolvedValue([
      { Id: "a001", Name: "City Hall", Town__c: "Pretoria" },
      { Id: "a002", Name: "City Bowl", Town__c: "Cape Town" }
    ]);
    const element = createComponent();
    const input = element.shadowRoot.querySelector("input");

    input.value = "City";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(300);
    await flushPromises();
    await Promise.resolve();

    const options = element.shadowRoot.querySelectorAll('[role="option"]');
    expect(options.length).toBe(2);
    expect(options[0].textContent).toContain("City Hall");
    expect(options[0].textContent).toContain("Pretoria");
  });

  it("selecting a result dispatches flow attribute change events and shows a pill", async () => {
    jest.useFakeTimers();
    search.mockResolvedValue([
      { Id: "a001", Name: "City Hall", Town__c: "Pretoria" }
    ]);
    const element = createComponent();
    const changeHandler = jest.fn();
    // sfdx-lwc-jest's FlowAttributeChangeEvent stub fires under the platform event name,
    // not the friendly "flowattributechange" alias used in real Flow runtime.
    element.addEventListener("lightning__flowattributechange", changeHandler);

    const input = element.shadowRoot.querySelector("input");
    input.value = "City";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(300);
    await flushPromises();
    await Promise.resolve();

    // Typing already dispatched change events to clear any prior selection;
    // isolate the events fired by the selection itself.
    changeHandler.mockClear();

    const option = element.shadowRoot.querySelector('[role="option"]');
    option.dispatchEvent(new CustomEvent("click"));
    await Promise.resolve();

    expect(element.selectedRecordId).toBe("a001");
    expect(element.selectedRecordLabel).toBe("City Hall");
    expect(
      element.shadowRoot.querySelector(".slds-pill__label").textContent
    ).toBe("City Hall");
    expect(changeHandler).toHaveBeenCalledTimes(3);
  });

  it("validate() fails when required and nothing is selected", () => {
    const element = createComponent({ required: true });
    const result = element.validate();
    expect(result.isValid).toBe(false);
    expect(result.errorMessage).toBeTruthy();
  });

  it("validate() passes when not required", () => {
    const element = createComponent({ required: false });
    const result = element.validate();
    expect(result.isValid).toBe(true);
  });

  it("does not show a create-new option when allowCreate is off, even with no results", async () => {
    jest.useFakeTimers();
    search.mockResolvedValue([]);
    const element = createComponent({ allowCreate: false });
    const input = element.shadowRoot.querySelector("input");

    input.value = "Nowhere";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(300);
    await flushPromises();
    await Promise.resolve();

    expect(element.shadowRoot.textContent).toContain(
      "No matching records found."
    );
    expect(element.shadowRoot.textContent).not.toContain("Create new");
  });

  it("shows a create-new option using the configured label prefix when allowCreate is on and nothing matches", async () => {
    jest.useFakeTimers();
    search.mockResolvedValue([]);
    const element = createComponent({
      allowCreate: true,
      createLabelPrefix: "Add"
    });
    const input = element.shadowRoot.querySelector("input");

    input.value = "Nowhere";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(300);
    await flushPromises();
    await Promise.resolve();

    expect(element.shadowRoot.textContent).toContain('Add "Nowhere"');
  });

  it('selecting "create new" sets requestNewRecord, shows a pill, and dispatches change events', async () => {
    jest.useFakeTimers();
    search.mockResolvedValue([]);
    const element = createComponent({ allowCreate: true });
    const changeHandler = jest.fn();
    element.addEventListener("lightning__flowattributechange", changeHandler);

    const input = element.shadowRoot.querySelector("input");
    input.value = "Nowhere";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(300);
    await flushPromises();
    await Promise.resolve();

    changeHandler.mockClear();

    const createOption = element.shadowRoot.querySelector('[role="option"]');
    createOption.dispatchEvent(new CustomEvent("click"));
    await Promise.resolve();

    expect(element.requestNewRecord).toBe(true);
    expect(element.selectedRecordId).toBeUndefined();
    expect(
      element.shadowRoot.querySelector(".slds-pill__label").textContent
    ).toBe('Create new "Nowhere"');
    expect(changeHandler).toHaveBeenCalledTimes(4);
  });

  it("clearing a create-new selection resets requestNewRecord", async () => {
    jest.useFakeTimers();
    search.mockResolvedValue([]);
    const element = createComponent({ allowCreate: true });

    const input = element.shadowRoot.querySelector("input");
    input.value = "Nowhere";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(300);
    await flushPromises();
    await Promise.resolve();

    element.shadowRoot
      .querySelector('[role="option"]')
      .dispatchEvent(new CustomEvent("click"));
    await Promise.resolve();

    element.shadowRoot
      .querySelector(".slds-pill__remove")
      .dispatchEvent(new CustomEvent("click"));
    await Promise.resolve();

    expect(element.requestNewRecord).toBe(false);
  });

  it("validate() passes when required and the user chose create-new", async () => {
    jest.useFakeTimers();
    search.mockResolvedValue([]);
    const element = createComponent({ allowCreate: true, required: true });

    const input = element.shadowRoot.querySelector("input");
    input.value = "Nowhere";
    input.dispatchEvent(new CustomEvent("input"));
    jest.advanceTimersByTime(300);
    await flushPromises();
    await Promise.resolve();

    element.shadowRoot
      .querySelector('[role="option"]')
      .dispatchEvent(new CustomEvent("click"));
    await Promise.resolve();

    const result = element.validate();
    expect(result.isValid).toBe(true);
  });
});
