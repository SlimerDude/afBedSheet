using web::WebReq
using afIoc::Inject

const class FileServer {
	
	@Inject
	private const Request req

	private const Uri:File dirMappings
	
	new make(Uri:File dirMappings, |This|in) {
		in(this)
		
		// TODO: allow non-dir uris to serve up single files
		
		// TODO: validate files are dirs and uris are correct
		
//    // validate pubPath
//    if (!pubPath.isPathOnly)
//		throw ArgErr("pubPath '$pubPath' must only have a path")
//    if (!pubPath.isPathAbs)
//		throw ArgErr("pubPath '$pubPath' must start with a '/'")
//    if (!pubPath.isDir)
//		throw ArgErr("pubPath '$pubPath' must end with a '/'")
		
		
		this.dirMappings = dirMappings.toImmutable
	}

	File service() {
		
		rt := req.route.pattern.replace("*", "").toUri
		
		pubDir := dirMappings[rt]
		
		routePath := req.routeRel
		
	    aa:= pubDir + routePath
		return aa
	}
}
