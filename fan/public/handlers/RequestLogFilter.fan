using afIoc::Inject
using afIoc::RegistryShutdownHub
using webmod::LogMod

**
** Uses [LogMod]`webmod::LogMod` to generate a server log file for all HTTP requests in the [W3C 
** Extended Log File Format]`http://www.w3.org/TR/WD-logfile.html`. 
** 
** To enable, contribute a `Route` for the filter (before all other routes) and set the log dir in 
** the config:
** 
** pre>
**   @Contribute { serviceType=Routes# }
**	 static Void contributeRoutes(OrderedConfig conf) {
**     
**     // put log filter first
**     conf.add(Route(`/***`, RequestLogFilter#service))
**     ...
**     // other routes here
**     ... 
**   }
** 
**   @Contribute { serviceType=ApplicationDefaults# } 
**   static Void contributeApplicationDefaults(MappedConfig conf) {
**     conf[ConfigIds.requestLogDir] = `/my/log/dir/`.toFile
**   }
** <pre
** 
** See `util::FileLogger` to configure datetime patterns for your log files.
** 
** The 'fields' property configures the format of the log records. It is a string of field names 
** separated by a space. The following field names are supported:
** 
**   - **date**: UTC date as DD-MM-YYYY
**   - **time**: UTC time as hh:mm:ss
**   - **c-ip**: the numeric IP address of the remote client socket
**   - **c-port**: the IP port of the remote client socket
**   - **cs-method**: the request method such as GET
**   - **cs-uri**: the encoded request uri (path and query)
**   - **cs-uri-stem**: the encoded path of the request uri
**   - **cs-uri-query**: the encoded query of the request uri
**   - **sc-status**: the return status code
**   - **time-taken**: the time taken to process request in milliseconds
**   - **cs(HeaderName)**: request header value such 'User-Agent'
** 
** If any unknown fields are specified or not available then "-" is logged. Example log record:
** 
**   2011-02-25 03:22:45 0:0:0:0:0:0:0:1 - GET /doc - 200 247
**     "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10"
**     "http://localhost/tag"
** 
const class RequestLogFilter {
	
	** Directory where the request log files are written.
	** 
	** @see `ConfigIds.requestLogDir`
	@Inject @Config { id="afBedSheet.requestLog.dir" } 
	const File? dir

	** Log filename pattern. 
	** 
	** @see `ConfigIds.requestLogFilenamePattern`
	@Inject @Config { id="afBedSheet.requestLog.filenamePattern" } 
	const Str filenamePattern

	** Format of the web log records as a string of names.
	** 
	** @see `ConfigIds.requestLogFields`
	@Inject @Config { id="afBedSheet.requestLog.fields" } 
	const Str fields

	private const LogMod logMod
	
	internal new make(RegistryShutdownHub shutdownHub, |This|in) { 
		in(this)
		
		if (dir == null)
			throw BedSheetErr(BsMsgs.requestLogFilterDirCannotBeNull)
		
		logMod = LogMod { it.dir=this.dir; it.filename=this.filenamePattern; it.fields=this.fields }
		logMod.onStart
		
		shutdownHub.addRegistryShutdownListener("RequestLogFilter", [,], |->| { logMod.onStop })
	}
	
	** Writes a request log entry.
	Void service(Uri remainingUri := ``) {
		logMod.onService
	}
}
