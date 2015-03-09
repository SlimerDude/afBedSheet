using web::WebReq
using afIoc

** (Service) - A Route Handler that maps URLs to files on the file system.
** 
** Suppose your project has this directory structure:
** 
** pre>
** myProj/
**  |-- fan/
**  |-- test/
**  `-- etc
**       `-- static-web/
**            |-- css/
**            |    `-- app.css
**            |-- images/
**            |    `-- logo.png
**            `-- scripts/
** <pre
** 
** Then to map the 'css/' dir add the following to 'AppModule':
** 
** pre>
** @Contribute { serviceType=FileHandler# }
** static Void contributeFileHandler(Configuration conf) {
**   conf[`/stylesheets/`] = `etc/static-web/css/`.toFile
** }
** <pre
** 
** Browsers may then access 'app.css' with the URL '/stylesheets/app.css'.
** 
** Rather than hardcoding '/stylesheets/app.css' in the HTML, it is better to generate a client URL from 'FileHandler'.
** 
**   url := fileHandler.fromLocalUrl(`/stylesheets/app.css`).clientUrl
** 
** Most of the time 'url' will be the same as the hardcoded URL but it has the added benefit of:
**  - Failing fast if the file does not exist
**  - generating correct URLs in non-root WebMods
**  - using asset caching strategies
**
** The generated 'clientUrl' contains any extra 'WebMod' path segments required to reach the 'BedSheet WebMod'.
** It also contains path segments as provided by any asset caching strategies, such as [Cold Feet]`http://www.fantomfactory.org/pods/afColdFeet`.
**  
** 
** 
** Serve All Root Directories [#serveAllDirs]
** ==========================================
** Using the above example, extra config would need to be added to serve the 'images/' and the 'scripts/' directories. 
** This is not ideal. So to serve all the files and directories under 'etc/static-web/' add config for the root URL:  
** 
**   conf[`/`] = `etc/static-web/`.toFile
** 
** This way everything under 'etc/static-web/' is served as is. Example, 'logo.png' is accessed with the URL '/images/logo.png'.
** 
** 
** 
** Fail Fast [#failFast]
** =====================
** An understated advantage of using 'FileHandler' to generate client URLs for your assets is that it fails fast.
** 
** Should an asset not exist on the file system (due to a bodged rename, a case sensitivity issue, or other) then 'FileHandler' will throw an Err on the server when the client URL is constructed.
** This allows your web tests to quickly pick up these tricky errors.
** 
** The lesser appealing alternative is for the incorrect URL to be served to the browser which on following, will subsequently receive a '404 - Not Found'.
** While this may not seem a big deal, these errors often go unnoticed and easily find their way into production.
** 
** 
** 
** Precedence with Other Routes [#RoutePrecedence] 
** ===============================================
** The 'FileHandler' directory mappings are automatically added to the `Routes` service on startup.
** That means it is possible to specify a 'Route' URL with more than one handler; a custom handler *and* this 'FileHandler'.
** With a bit of configuration it is possible to specify which takes precedence. 
**   
** The 'FileHandler' route contributions are set with the ID 'afBedSheet.fileHander', so when 'Route' precedence is important, use it in your config: 
** 
** pre>
** @Contribute { serviceType=Routes# }
** static Void contributeRoutes(Configuration config) {
** 
**   // this Route will be served in place of the file 'url1.txt'
**   config.set("beforeExample", Route(`/url1.txt`, ...)).before("afBedSheet.fileHandler")
** 
**   // this Route will be served if there is no file called 'url2.txt'
**   config.set("afterExample", Route(`/url2.txt`, ...)).after("afBedSheet.fileHandler")
** }
** <pre
** 
** @uses Configuration of 'Uri:File'
const mixin FileHandler {

	** Returns the map of URL to directory mappings
	abstract Uri:File directoryMappings()
	
	** The (boring) Route handler method. 
	** Returns a 'FileAsset' as mapped from the HTTP request URL or null if not found.
	abstract FileAsset? serviceRoute(Uri remainingUrl)	
	
	** Given a local URL (a simple URL relative to the WebMod), this returns a corresponding (cached) 'FileAsset'.
	**  
	**   url := fileHandler.fromLocalUrl(`/stylesheets/app.css`).clientUrl
	** 
	** Throws 'ArgErr' if the URL is not mapped.
	** Throws 'ArgErr' if checked and the file does not exist. 
	abstract FileAsset fromLocalUrl(Uri localUrl, Bool checked := true)

	** Given a file on the server, this returns a corresponding (cached) 'FileAsset'.
	**  
	** Throws 'ArgErr' if the file directory is not mapped.
	** Throws 'ArgErr' if checked and the URL does not exist. 
	abstract FileAsset fromServerFile(File serverFile, Bool checked := true)
	
	** Finds the directory mapping that best fits the given local URL, or 'null' if not found.
	@NoDoc	// Experimental advanced use - see Duvet
	abstract Uri? findMappingFromLocalUrl(Uri localUrl)
}

internal const class FileHandlerImpl : FileHandler {
	
	@Inject	private const HttpRequest? 			httpRequest	// nullable for unit tests
	@Inject	private const FileAssetCache		fileCache
			override const Uri:File 			directoryMappings
		
	new make(Uri:File dirMappings, |This|? in) {
		in?.call(this)
		
		// verify file and uri mappings, normalise the files
		this.directoryMappings = dirMappings.map |file, uri -> File| {
			if (!file.exists)
				throw BedSheetErr(BsErrMsgs.fileNotFound(file))
			if (!file.isDir)
				throw BedSheetErr(BsErrMsgs.fileIsNotDirectory(file))
			if (!uri.isPathOnly)
				throw BedSheetErr(BsErrMsgs.urlMustBePathOnly(uri, `/foo/bar/`))
			if (!uri.isPathAbs)
				throw BedSheetErr(BsErrMsgs.urlMustStartWithSlash(uri, `/foo/bar/`))
			if (!uri.isDir)
				throw BedSheetErr(BsErrMsgs.urlMustEndWithSlash(uri, `/foo/bar/`))
			return file.normalize
		}
	}

	override FileAsset? serviceRoute(Uri remainingUri) {
		try {
			// use pathStr to knockout any unwanted query str
			return fromLocalUrl(httpRequest.url.pathStr.toUri)
		} catch 
			// don't bother making fromLocalUrl() checked, it's too much work for a 404!
			// null means that 'Routes' didn't process the request, so it continues down the pipeline. 
			return null
	}
	
	override Uri? findMappingFromLocalUrl(Uri localUrl) {
		Utils.validateLocalUrl(localUrl, `/css/myStyles.css`)
		// TODO: what if 2 dirs map to the same url at the same level?

		// match the deepest uri
		prefixes:= directoryMappings.keys.findAll { localUrl.toStr.startsWith(it.toStr) }
		prefix 	:= prefixes.size == 1 ? prefixes.first : prefixes.sort |u1, u2 -> Int| { u1.path.size <=> u2.path.size }.last
		return prefix
	}

	override FileAsset fromLocalUrl(Uri localUrl, Bool checked := true) {
		prefix	:= findMappingFromLocalUrl(localUrl)
				?: throw BedSheetNotFoundErr(BsErrMsgs.fileHandler_urlNotMapped(localUrl), directoryMappings.keys)

		// We pass 'false' to prevent Errs being thrown if the uri is a dir but doesn't end in '/'.
		// The 'false' appends a '/' automatically - it's nicer web behaviour
		remaining := localUrl.getRange(prefix.path.size..-1).relTo(`/`)
		file	  := directoryMappings[prefix].plus(remaining, false)

		return fromServerFile(file, checked)
	}

	override FileAsset fromServerFile(File file, Bool checked := true) {
		fileCache.getOrAddOrUpdate(file) |File f->FileAsset| {
			if (file.uri.isDir)
				throw ArgErr(BsErrMsgs.fileIsDirectory(file))
			if (!file.exists && checked)
				throw ArgErr(BsErrMsgs.fileNotFound(file))
			
			fileUri	:= file.normalize.uri.toStr
			prefix  := (Uri?) directoryMappings.eachWhile |af, uri->Uri?| { fileUri.startsWith(af.uri.toStr) ? uri : null }
			if (prefix == null)
				throw BedSheetNotFoundErr(BsErrMsgs.fileHandler_fileNotMapped(file), directoryMappings.vals.map { it.osPath })
			
			matchedFile := directoryMappings[prefix]
			remaining	:= fileUri[matchedFile.uri.toStr.size..-1]
			localUrl	:= prefix + remaining.toUri
			clientUrl	:= fileCache.toClientUrl(localUrl, file)
			
			return FileAsset(f, localUrl, clientUrl)
		}
	}
}
