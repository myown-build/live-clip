import { createClient } from '@supabase/supabase-js'


function mount_video(url, mount_el) {
  const video_el = document.createElement('video');
  video_el.src = url;
  video_el.controls = true;
  // video_el.class = "";
  mount_el.appendChild(video_el);
}

let WatcherHook = {
  mounted() {
    console.log("mounted", this.el, this.el.dataset);
    let {
      supabaseUrl, 
      supabaseKey, 
      videoId, 
      authToken
    } = this.el.dataset;

    const supabase = createClient(supabaseUrl, supabaseKey);
    window.supabase = supabase;

    if (authToken) {
      console.log("auth token", authToken);

      supabase.auth
        .verifyOtp({ token_hash: authToken, type: 'email'})
        .then(({data, error}) => {
          console.log(data, error);
          this.pushEvent({})
        })
    }

    this.handleEvent("clip:upload", async (params) => {
      console.log("clip:upload", params, supabase);

      const file_input = document.getElementById("file-input");

      if (file_input.files.length > 0) {
        // const buffer = await file_input.files[0].arrayBuffer();
        const video_file = file_input.files[0];
        console.log("uploading video file");
        // supabase.
        // const { data, error } = await supabase
        //   .storage
        //   .from('videos')
        //   .upload(`${params.id}.mp4`, video_file, {
        //     cacheControl: '3600',
        //     upsert: false
        //   });
      }


    });

    if (videoId) {
      const name = `${videoId}.mp4`
      
      let { data } = supabase.storage.from('videos').getPublicUrl(name);
      const { publicUrl } = data;

      supabase.storage.from('videos').exists(name).then(({ data }) => {
        const exists = data == true;

        if (exists) {          
          mount_video(publicUrl, this.el);
        } else {
          this.handleEvent("viewer:update", (event) => {
            console.log(event);

            mount_video(publicUrl, this.el);
          })
          this.pushEvent("viewer:poll", {id: videoId});
        }
      });
    }
  }
};

export default { WatcherHook }