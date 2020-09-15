import { ajax } from 'discourse/lib/ajax';
import { withPluginApi } from "discourse/lib/plugin-api";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Application from "@ember/application";
import { on } from "@ember/object/evented";
//could update the highlight to hit on the split(" ") aswell. If, you know, i feel like it.

Application.myMainContext = Ember.Component.extend({
  myAws: "",
  subbedReps: [],
  showComponent: false,
  ranOnce: false,
  tagTrigger: 1,
  mainRepInit: false,
  signedIn: null,
  //update the suggested options to follow for representatives in the input box

  updatePossibles: function (substr) {
    var compContext = this; //component context
    if (substr == "") {
      return;
    }
    //get suggestions
    substr = encodeURIComponent(substr); //GET POST

    ajax(`/meritmoot/reps/search/${substr}.json`, { type: "GET" }).then( result => {
      result = result.api;
      let pv = []; //possible values
      for(let i = 0; i < result.length; i++) {
        let newItem = {
          label: result[i].mm_reference_str,
          value: result[i].id,
          id: result[i].id,
        }
        pv.push(newItem);
      }
      //note interaction with rep-input
      Application.meritmoot.myAwesomeInput.list = pv;
      //update Awesomplete internal logic
      Application.meritmoot.myAwesomeInput.evaluate();
      //show Awesomplete suggestions
      Application.meritmoot.myAwesomeInput.open();
    });
  },
  registerDelete: function (id) {
    var compContext = this;
    document.getElementById("representativeInfo").addEventListener('click', function (e) {
      let repexit = "rep" + id + "x";
      repexit = document.getElementById(repexit);
      if(e.srcElement == repexit){
        let subbedReps = compContext.get("subbedReps");
        for(let index = 0; index < subbedReps.length; index += 1){
          if(subbedReps[index].id == id){
            ajax(`/meritmoot/reps/${id}`, { type: "DELETE" }).catch(e => {
              if (!(403 == e.jqXHR.status)) {
                console.log("throwing delete error")
                throw e
              }
            });
            subbedReps.splice(index, 1)
            compContext.set("subbedReps", subbedReps);
            compContext.notifyPropertyChange("subbedReps")
            return;
          }
        }
      }
    }, false);
  },
  awes_select: function(e) {
    //event added in mminit, removed in willdestroy

    var substrInput = document.getElementById("rep-input");
    if(e.srcElement == substrInput) {
      //as we dont directly call the function, need to pass context in externally
      var compContext = Application.meritmoot.myMainContext;

      //set input value to nothing
      let id = e.text.value;
      substrInput.value = "";

      //send selection backend
      let uriid = encodeURIComponent(id);
      ajax(`/meritmoot/reps/${uriid}`, {type: "PUT" }).catch( result => {
        //dont die if it doesnt go through due to authentication / conflict
      })

      //delete replicants
      for(let i = 0; i < compContext.subbedReps.length; i+=1 ) {
        if (compContext.subbedReps[i].id == id) {
          delete compContext.subbedReps.splice(i, 1);
          compContext.notifyPropertyChange("subbedReps");
          break;
        }
      }
      
      //update selection frontend
      let l = compContext.get("subbedReps");
      l.pushObject({
        id: id,
        mm_reference_str: e.text.label
      });//pushObject is needed instead of push (https://github.com/emberjs/ember.js/issues/10405)
        
      compContext.set("subbedReps", l);
      compContext.registerDelete(id);
      //1. DONE create a table that matches user id to subscribed reps.
      //2. DONE create a way to add subscribed reps to that table. in progress (need GET PUT DELETE)
      //3. DONE reps next to substrInput
      //3. create a way to view votes next to topics.
      //4. after all that, refresh that mechanism of viewing votes here and down by the other registerDelete
    }
  },
  awes_input: function(e) {
    //event added in mminit, removed in willdestroy
    //as we dont directly call the function, need to pass context in externally
    var substrInput = document.getElementById("rep-input");
    if(e.srcElement == substrInput) {
      var compContext = Application.meritmoot.myMainContext;
      compContext.updatePossibles(substrInput.value);
    }
  },
  mminit: function () {
    //let us know it ran...
    //list context globaly to avoid some of the more headache inducing factors of having logic
    //spanning two distinct templates, and also the factors of emberjs generally.
    console.log("initing")
    if(! Application.meritmoot.myMainContext) {
      Application.meritmoot.myMainContext = this;
    }
    
    document.addEventListener('awesomplete-selectcomplete', this.awes_select , false);
    document.addEventListener('input', this.awes_input, false)

    //get users saved representatives, show them.

    var compContext = this;
    withPluginApi("0.8.7", (api) => {
      this.set("signedIn", api.getCurrentUser())
    });
    if(this.get("signedIn") != null) {
      ajax(`/meritmoot/reps.json`, {type: "GET"}).then( result => {
        //dont want to replace things in subbedReps as it will delete and remake them, causing race conditions
        //as it all happens at one time which are really fucking annoying
        let mainList = this.get("subbedReps")
        let updatedList = result.mmfollows;
        let mainListTags = []
        for(let n = 0; n < mainList.length; n++){
          mainListTags.push(mainList[n].mm_reference_str)
        }
        console.log("rep-main-main-list-tags")
        console.log(mainListTags)
        //console.log(mainList)
        //console.log(updatedList)
        
        for(let n = 0; n < updatedList.length; n++) {
          //if it does include, do nothing. dont mess with it.
          //if it does not include, add it.
          if(! mainListTags.includes(updatedList[n].mm_reference_str)) {
            mainList.pushObject(updatedList[n])
          }
          //the question then becomes what if there is something in the mainList, but not in our updatedList?
          //basically, it shouldn't happen given the logical flow of the program. On object deletion, it 
          //immediately follows to the backend. Probably should have conditions for this, but.
        }
        console.log("main list after")
        console.log(mainList)
        this.set("subbedReps", mainList)
        //adding future deletion using the "x" button on the tag.
        for(let rep = 0; rep < mainList.length; rep+=1) {
          compContext.registerDelete(mainList[rep].id);
        }
      }).catch(e => {
        console.log("meritmoot-reps url catch")
        console.log(e)
        if ( !(403 == e.jqXHR.status) ) {
          throw e
        }
      });
    }
  },
  _init3: on("init", function() {
    Application.meritmoot.myMainComponent = this;
    var repMainContext = this;
    withPluginApi("0.8.7", (api) => {
      api.onAppEvent("url:refresh", () => {
        if (!repMainContext.isDestroyed && !repMainContext.isDestroying) { 
          console.log("rep-url-refresh")
          repMainContext.set("mainRepInit", true) 
        }
      });
      api.modifyClass( "component:topic-list", {
        _init3: on("init", function() {
          if (!repMainContext.isDestroyed && !repMainContext.isDestroying) { 
            console.log("rep-main-topiclist-init")
            repMainContext.set("mainRepInit", true) 
          }
        }),
        didRender() {
          console.log("rep-main-topiclist-rend-unt")
          if(!repMainContext.isDestroyed && !repMainContext.isDestroying && repMainContext.get("mainRepInit") && repMainContext.get("ranOnce")) {
            console.log("rep-main-topiclist-triggered")
            console.log("IT CHANGED")
            console.log(repMainContext.get("mainRepInit"))
            console.log(repMainContext.get("ranOnce"))
            repMainContext.set("mainRepInit", false)
            repMainContext.set("tagTrigger", repMainContext.get("tagTrigger") + 1)
          }
          this._super(...arguments);
        }
      });
      api.modifyClass("component:categories-topic-list", {
        _init3: on("init", function() {
            if (!repMainContext.isDestroyed && !repMainContext.isDestroying) { 
              console.log("main-cat-top-list-init")
              repMainContext.set("mainRepInit", true) 
            }
          }),
        didRender() {
          console.log("main-cat-top-list-rend-unt")
          if (!repMainContext.isDestroying && !repMainContext.isDestroyed && repMainContext.get("mainRepInit") && repMainContext.get("ranOnce")) {
            console.log("main-cat-top-list-triggered")
            console.log("IT CHANGED")
            console.log(repMainContext.get("mainRepInit"))
            console.log(repMainContext.get("ranOnce"))
            repMainContext.set("mainRepInit", false)
            repMainContext.set("tagTrigger", repMainContext.get("tagTrigger") + 1)
          }
          return this._super(...arguments)
        }
      })
    });
  }),
  didRender() {
    this._super(...arguments);
    //i dont really get emberjs too much - so apologies to whoever has to clean this mess up lmao
    if( this.get("ranOnce") != true ) {
      console.log("mainRepInit")
      this.set("showComponent", true)
      this.mminit()
      this.set("ranOnce", true)
    }
  },
  willDestroy() {
    console.log("rep-main-will-destroy")
    document.removeEventListener('awesomplete-selectcomplete', this.awes_select);
    document.removeEventListener('input', this.awes_input)
    this.set("subbedReps", [])
    this._super(...arguments);
  },
});
export default Application.myMainContext;
