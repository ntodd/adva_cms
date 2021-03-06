var Flash = {
	transferFromCookies: function() {
	  var data = JSON.parse(unescape(Cookie.get("flash")));
	  if(!data) data = {};
	  Flash.data = data;
	  Cookie.erase("flash");
	},
  // When given an flash message, wrap it in a list and show it on the screen.  
  // This message will auto-hide after a specified amount of milliseconds
  show: function(flashType, message) {
    // new Effect.ScrollTo('flash-' + flashType);
    $('flash-' + flashType).innerHTML = '';
    if(message.toString().match(/<li/)) message = "<ul>" + message + '</ul>'
    $('flash-' + flashType).innerHTML = message;

		if(Flash.applyEffects) {
    	new Effect.Appear('flash-' + flashType, {duration: 0});
    	//ssetTimeout(Flash['fade' + flashType[0].toUpperCase() + flashType.slice(1, flashType.length)].bind(this), 5000)
		} else {
			$('flash-' + flashType).show();
		}
  },
  errors: function(message) {
    this.show('error', message);
  },
  notice: function(message) {
    this.show('notice', message);
  },  
  // Responsible for fading notices level messages in the dom    
  fadeNotice: function() {
    new Effect.Fade('flash-notice', {duration: 1});
    // new Effect.BlindUp('flash-notice', {duration: 1});
  },  
  // Responsible for fading error messages in the DOM
  fadeError: function() {
    new Effect.Fade('flash-error', {duration: 1});
  }
}
Flash.data = {};
Flash.applyEffects = true;

Event.onReady(function() {
	Flash.transferFromCookies();
  ['notice', 'error'].each(function(type) {		
    if(Flash.data[type]) Flash.show(type, Flash.data[type].toString().gsub(/\+/, ' '));
  })
});
