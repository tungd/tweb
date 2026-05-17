(function () {
  "use strict";

  window.__twebPageAgentReady = true;
  window.__twebPageAgent = {
    async runTwebTask(task, context) {
      return {
        text: "completed: " + task,
        compactEvidence: [
          {
            source: "controlled-page",
            quote: "PageAgent fixture executed the task"
          }
        ],
        context: context || {}
      };
    }
  };
})();
