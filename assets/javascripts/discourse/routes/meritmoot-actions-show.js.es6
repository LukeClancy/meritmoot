import DiscourseRoute from 'discourse/routes/discourse'
import { ajax } from 'discourse/lib/ajax';

export default DiscourseRoute.extend({
  controllerName: "actions-show",

  model() {
    ajax("/reps/search/" + params + ".json", {type: 'GET'}).then((result) => {
      return result
      /* console.log(result)
      result = JSON.parse(result)
      repList = document.getElementById("rep-list")
      repList.innerHTML = ""
      result.forEach(op => {
        var x = document.createElement("INPUT");
        x.setAttribute("info-tag-id", op.id)
        x.setAttribute("value", op.mm_reference_str)
        repList.appendChild(x)
      });
      console.log(repList)
      return repList */
    });
  },

  renderTemplate() {
    this.render("representatives");
  }
});
