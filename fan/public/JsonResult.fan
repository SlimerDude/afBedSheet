using util::JsonOutStream

** Return from Handler methods to send a JSON response to the client.
**
** This is purposely a concrete final class so there's no ambiguity as to what it is. For example, 
** if a handler returned an Obj that was both a 'TextResult' and a "JsonResult' what is BedSheet 
** supposed to do? 
** 
** Best practice is to have your Entities have a 'toText()' or 'toJson()' method and return that.
** 
** pre>
** Obj myHandler(MyEntity entity) {
**   ...
**   return entity.toJson
** }
** <pre  
final class JsonResult {
	
	private Obj jsonObj
	private Str? callback

	** The jsonObj should be serialisable into Json via `JsonOutStream`
	new make(Obj jsonObj) {
		this.jsonObj = jsonObj
	}

	new makeFromJsonp(Str callback, Obj jsonObj) {
		this.jsonObj = jsonObj
		this.callback = callback
	}
	
	** Converts the wrapped Obj into JSON via `JsonOutStream.writeJsonToStr`
	Str toJsonStr() {
		if (callback == null)
			return JsonOutStream.writeJsonToStr(jsonObj)
		
		return "$callback(${JsonOutStream.writeJsonToStr(jsonObj)});"
	}
	
	// FIXME: munge into TextResult once the IE hacks have been moved to a filter
}
