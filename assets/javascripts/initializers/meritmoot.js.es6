import { withPluginApi } from "discourse/lib/plugin-api";
import Application from "@ember/application"
import EmberObject from "@ember/object";
//import { ajax } from 'discourse/lib/ajax';

console.log("MeritMoot Javascript Reached")

Application.meritmoot = EmberObject.create({
  checkPage: function(url) {
    var loc = url
    let eq = (loca, comp) => loca == comp
    let inc = (loca, comp) => loca.includes(comp)
    let allowedLocations = [
      loca => eq(loca,  "/"),
      loca => eq(loca,  "/latest"),
      loca => eq(loca,  "/new"),
      loca => eq(loca,  "/top"),
      loca => inc(loca, "/c/bills"),
      loca => inc(loca, "/c/roll-calls"),
      loca => eq(loca,  "/categories")
    ]
    for(let i = 0; i < allowedLocations.length; i+=1){
      if(allowedLocations[i](loc)){
        return true;
      }
    }
    return false;
  },
  myAwesomeInput: undefined,
  myInputContext: undefined,
  myMainContext: undefined,
})

export default {
  name: "meritmoot",
  initialize() {
    console.log("INIT")
    withPluginApi("0.8.7", (api) => {
      
    })
  }
};
  

//repInput.onchange = function(this) {

    
    //  console.log("inside initializeMeritmoot")
     // function repInputKeyUp() {
    //    inputBox = document.getElementById("rep-input")
    //    console.log("in rep input key up")
    //    
    //  };
    //  console.log("Past Function Def");
//
  //    window.addEventListener('onload', function() {
    //    console.log("PageLoaded")
     //   document.getElementById('rep-input').onkeyup = repInputKeyUp;
     // }, false);
//
 //     console.log('leaving initializeMeritmoot');
  //  }

 //   console.log("MeritMoot Javascript In Default")