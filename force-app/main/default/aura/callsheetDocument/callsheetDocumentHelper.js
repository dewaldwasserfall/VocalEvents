({
    getCallsheetImage: function(component) {
        var action = component.get("c.getCallsheetImageDocument");
        var bookingFormId = component.get("v.recordId");
        action.setParams({ bookingFormId: bookingFormId });

        // Set the callback for the Apex call
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var document = response.getReturnValue();
                if (document) {
                    component.set("v.contentDocument", document);
                    component.set("v.hasDocument", true);
                } else {
                    component.set("v.hasDocument", false);
                }
            } else if (state === "ERROR") {
                var errors = response.getError();
                if (errors && errors[0] && errors[0].message) {
                    console.error("Error message: " + errors[0].message);
                }
            }
        });

        // Send the action off to be executed
        $A.enqueueAction(action);
    }
})