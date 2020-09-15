//logic in rep-main utilizing getElementById
import Application from "@ember/application";
import { withPluginApi } from "discourse/lib/plugin-api";

Application.RepInputComponent = Ember.Component.extend({
  showInputComponent: false,
  mminit: function() {
    console.log("rep-input-mminit")
    var substrInput = document.getElementById("rep-input");
    
    //create custom Awesomplete (options list) for substrInput (rep-input).
    Application.meritmoot.myAwesomeInput = new Awesomplete(substrInput);

    //all list items should be shown, as they are selected with predjudice on substr value change
    Application.meritmoot.myAwesomeInput.filter = function (text, input) {
      return true;
    }

    //show whenever, turn autocomplete on.
    Application.meritmoot.myAwesomeInput.minChars = 0;
    Application.meritmoot.myAwesomeInput.autocomplete = "on";
  },
  didRender() {
    this._super(...arguments);
    var repInputContext = this;
    if (! this.get("runOnceRan") ) {
      withPluginApi("0.8.7", (api) => {
        this.set("showInputComponent", true);
        api.onPageChange((url, title) => {
          //let context = Application.RepInputComponent;
          if (repInputContext.isDestroyed || repInputContext.isDestroying) {
            return
          }
          if (repInputContext && Application.meritmoot.checkPage(url)){
            repInputContext.mminit()
          }
        });
        api.onAppEvent("url:refresh", () => {
          //console.log("inp-ref")
          if (repInputContext.isDestroyed || repInputContext.isDestroying) {
            return
          }
          if (repInputContext && Application.meritmoot.checkPage(window.location.pathname)){
            repInputContext.mminit()
          }
        });
      });
      this.set("runOnceRan", true)
    }
  },
  willDestroy() {
    console.log("rep-input-will-destroy")
    console.log(Application.meritmoot.myAwesomeInput)
    if(Application.meritmoot.myAwesomeInput != "" && Application.meritmoot.myAwesomeInput != undefined) {
      Application.meritmoot.myAwesomeInput.destroy()
      Application.meritmoot.myAwesomeInput = ""
    }
    this._super(...arguments);
  }
});
export default Application.RepInputComponent;