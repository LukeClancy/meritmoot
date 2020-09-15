import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from 'discourse/lib/ajax';
import Application from "@ember/application";
import { on } from "@ember/object/evented";
import { observes } from "discourse-common/utils/decorators";



//I AM SO CLOSE >:D

Application.RepTagComponent = Ember.Component.extend({
  tagInfo: "THIS IS TAG INFO",
  runOnceRan: false,
  topicIds: [], //ids of the vote tag elements created, later to be used for destruction
  createTagItem: function(item, tagName) {
    //class: topic-list -> [enum] class: topic-list-item -> class: discourse-tags -> append to children end
    //let topic_id = item.attributes["data-topic-id"].value;
    let classNames = "discourse-tag box " + " mmtag_" + this.get("id");
    let tagList = item.getElementsByClassName("discourse-tags")[0];
    for(let x = 0; x < tagList.children.length; x+=1) {
      if(tagList.children[x].innerHTML == tagName && tagList.children[x].className == classNames ) {
        //sometimes it runs twice for reasons. I gave up on stopping it, this whole front end has become a bit of a shit show
        return
      }
    }
    var newTag = document.createElement("a");
    newTag.className = classNames
    newTag.innerHTML = tagName;
    //newTag.href = "https://duckduckgo.com/";
    
    //console.log("tagList - newTag")
    //console.log(tagList);
    //console.log(newTag);
    tagList.appendChild(newTag);
  },
  processList: function(topicItems) {
    let domInf = {};
    let getInf = [];
    let debug = [];
    console.log("rep-tag-listing-children")
    for(let i = 0; i < topicItems.length; i += 1) {
      let topItem = topicItems[i]
      debug.push(topItem.attributes["data-topic-id"]);
      if(topItem.attributes["data-topic-id"] != undefined) {
        domInf[topItem.attributes["data-topic-id"].value] = topItem;
        getInf.push(topItem.attributes["data-topic-id"].value);
      }
    }
    console.log(debug);
    ajax(`/meritmoot/reps/${this.get("id")}/votes.json`, { type: "POST", data: {topicList: getInf} }).then( response => {
      let topics = response['topics']
      //console.log("rep-tag-topics: returned, ids")
      //console.log(topics)
      let topic_ids = Object.keys(topics)
      //console.log(topic_ids)
      let tags_created = 0
      //let status = response['status']
      //status: "OK",
      //topics : {
      //    topic_id => [{name: "john: yes"}, {name: "john: cosponsored"}]
      //  }, ... ]
      for(let i = 0; i < topic_ids.length; i += 1) {
        let tid = parseInt(topic_ids[i])
        let tags = topics[tid]
        for(let n = 0; n < tags.length; n += 1) {
          this.createTagItem( domInf[tid], tags[n]['name'])
          tags_created += 1
        }
      }
    });
  },
  topicListChange: function(mutationsList, observer) {
    let newTopics = [];
    for(let x = 0; x < mutationsList.length; x += 1) {
      if(mutationsList[x].addedNodes.length >= 1){
        let mut = mutationsList[x].addedNodes[0];
        if(mut['nodeName'] == "TR"){
          newTopics.push(mut);
        }
      }
    }
    observer.context.processList(newTopics);
  },
  getTopicList: function() {
    // get topiclist such that topicList.children returns topics
    let x = -1
    var topicList = ""
    while(topicList == undefined || (! topicList instanceof HTMLCollection) || topicList.length == 0) {
      x += 1
      if(x == 0){
        topicList = document.getElementsByClassName("topic-list");
      } else if (x == 1) {
        topicList = document.getElementsByClassName("latest-topic-list");
      } else if (x == 2) {
        topicList = document.getElementsByClassName("top-topic-list");
      } else {
        return undefined
      }
    }
    if(x == 0) {
      let i = 0;
      for(i = 0; i < topicList[0].children.length; i+=1) {
        if(topicList[0].children[i]['nodeName'] == "TBODY") {
          break
        }
      }
      topicList = topicList[0].children[i]
    }
    if(x == 1 || x == 2) {
      topicList = topicList[0]
    }
    return topicList
  },
  topicListObserver: "TOPIC LIST OBSERVER NOT SET",
  mminit: function() {
    console.log("tag-mminit")
    var topicListObserver = undefined
    let topicList = this.getTopicList()
    console.log("topicList")
    console.log(topicList)
    //process items on update
    topicListObserver = new MutationObserver(this.topicListChange);
    topicListObserver.context = this
    if(this.get("topicListObserver") != undefined && this.get("topicListObserver") instanceof MutationObserver) {
      this.get("topicListObserver").disconnect()
    }
    this.set("topicListObserver", topicListObserver)
    var config = {childList: true}
    this.get("topicListObserver").observe(topicList, config)
    //process items immediately loaded
    let topicItems = topicList.children
    //console.log("topicItems")
    //1console.log(topicItems)
    this.processList(topicItems);
  },
  @observes("tagTrigger")
  mminit_trigger() {
    console.log("tag-taglist-triggered")
    this.mminit()
  },
  didRender() {
    this._super(...arguments);
    //bugs are fun.
    if (! this.get("runOnceRan") ) {
      this.set("runOnceRan", true)
      this.mminit()
      //these two detect when I need to refresh the tag tracking system.
      //the time interval is so that it doesn't overlap signals
      withPluginApi("0.8.7", (api) => {
        //first creation step is tricky. we allow three seconds and then hand
        //to page change / refresh steps
        console.log("initial mminit")

        //this one attaches to topic-list and initializes (with above input) at the appropriate time (after a topic-list render)
        //var repTagContext = this;
        /*
        api.modifyClass("component:topic-list", {
          allRepTags: [],
          runRepTags: [],
          
          _init2: on("init", function() {
            //cant initialize here as we are not rendered.
            //subscribe to initialize
            console.log("rep-tag-taglist-init")
            let at = this.get("allRepTags")
            if(! at.includes(repTagContext.id)){
              at.pushObject(repTagContext.id)
              this.set("allRepTags", at)
            }
            this.set("runRepTags", at)
            console.log("rep-tag-taglist-followed [" + this.get("allRepTags").toString() + "]")
          }),
          didRender() {
            console.log("rep-tag-taglist-rendered")
            console.log(this.get("runRepTags"))
            //if our tag is not destroyed and we hab
            if(!repTagContext.isDestroyed && !repTagContext.isDestroying && this.get("runRepTags").includes(repTagContext.id) ) {
              //add to those ran once
              let ro = this.get("runRepTags")
              let idIndex = ro.indexOf(repTagContext.id)
              ro.splice(idIndex, 1)
              this.set("runRepTags", ro)
              //log and mminit
              console.log("rep-tag-taglist-mminit");
              repTagContext.mminit()
            }
            this._super(...arguments);
          }
        })*/
      });
    }
  },
  willDestroy() {
    console.log("rep-tag-will-destroy")
    //console.log(this.get("topicListObserver"))
    if(this.get("topicListObserver") != undefined && this.get("topicListObserver") instanceof MutationObserver) {
      this.get("topicListObserver").disconnect()
    }
    let topicList = this.getTopicList()
    if( topicList != undefined ) {
      let tags = topicList.getElementsByClassName("mmtag_" + this.get("id"))
      while(tags.length >= 1){
        console.log('-')
        tags[tags.length - 1].parentNode.removeChild(tags[tags.length - 1]);
      }
    }
    this._super(...arguments);
  }
});
export default Application.RepTagComponent;
