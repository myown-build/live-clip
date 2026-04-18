// import { Popcorn } from "@swmansion/popcorn";

import { createClient } from '@supabase/supabase-js'
// Create a single supabase client for interacting with your database

// let yami = {};
// window.yami = yami;

let WatcherHook = {
  mounted() {
    console.log("mounted", this.el, this.el.dataset);
    let {supabaseUrl, supabaseKey} = this.el.dataset;

    const supabase = createClient(supabaseUrl, supabaseKey);
    window.supabase = supabase;

    this.handleEvent("client:call", (params) => {
      console.log("client:call", params, supabase);
    })

  }
};

export default { WatcherHook }