export default function() {
  this.route("meritmoot", function() {
     this.route("reps", { path: "/:substr"}),
    this.route("actions", function() {
      this.route("show", { path: "/:id" });
    });
  });
};
