import { acceptance } from "helpers/qunit-helpers";

acceptance("meritmoot", { loggedIn: true });

test("meritmoot works", async assert => {
  await visit("/admin/plugins/meritmoot");

  assert.ok(false, "it shows the meritmoot button");
});
