document.addEventListener("turbo:load", function () {
  function syncTrashButtons(container) {
    var blocks = container.querySelectorAll(".booking-dynamic-block");
    var hideTrash = blocks.length <= 1;

    blocks.forEach(function (block) {
      var trashButton = block.querySelector("[data-remove-block]");
      if (!trashButton) return;

      if (hideTrash) {
        trashButton.classList.add("booking-trash-button--hidden");
      } else {
        trashButton.classList.remove("booking-trash-button--hidden");
      }
    });
  }

  function syncDayRows(container) {
    var dayRows = container.querySelectorAll(".booking-multi-day-row");
    dayRows.forEach(function (row) {
      var checkbox = row.querySelector("input[type='checkbox'][name$='[selected]']");
      if (!checkbox) return;

      var enabled = checkbox.checked;
      var timeFields = row.querySelectorAll("input[type='time']");

      timeFields.forEach(function (field) {
        field.disabled = !enabled;
      });

      if (enabled) {
        row.classList.remove("booking-multi-day-row--disabled");
      } else {
        row.classList.add("booking-multi-day-row--disabled");
      }
    });
  }

  function bindDynamicBlockManager(config) {
    var addButton = document.getElementById(config.addButtonId);
    var container = document.getElementById(config.containerId);
    var template = document.getElementById(config.templateId);
    if (!addButton || !container || !template) return;

    if (!addButton.dataset.listenerBound) {
      addButton.addEventListener("click", function () {
        var currentCount = container.querySelectorAll(".booking-dynamic-block").length;
        var html = template.innerHTML
          .replaceAll("__INDEX__", String(currentCount))
          .replaceAll("__INDEX_LABEL__", String(currentCount + 1));
        container.insertAdjacentHTML("beforeend", html);
        syncTrashButtons(container);
        syncDayRows(container);
      });
      addButton.dataset.listenerBound = "1";
    }

    if (!container.dataset.listenerBound) {
      container.addEventListener("click", function (event) {
        var removeButton = event.target.closest("[data-remove-block]");
        if (!removeButton) return;

        var targetBlock = removeButton.closest(".booking-dynamic-block");
        if (!targetBlock) return;

        targetBlock.remove();
        syncTrashButtons(container);
        syncDayRows(container);
      });

      container.addEventListener("change", function (event) {
        if (!event.target.matches("input[type='checkbox'][name$='[selected]']")) return;
        syncDayRows(container);
      });
      container.dataset.listenerBound = "1";
    }

    syncTrashButtons(container);
    syncDayRows(container);
  }

  bindDynamicBlockManager({
    addButtonId: "add-enseigne-button",
    containerId: "enseigne-fields-container",
    templateId: "enseigne-block-template"
  });

  bindDynamicBlockManager({
    addButtonId: "add-staff-button",
    containerId: "staff-fields-container",
    templateId: "staff-block-template"
  });
});
