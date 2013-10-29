using afIoc::Inject
using web::WebRes

** @Inject - Sends the status code and msg from `HttpStatusErr` to the client. 
@NoDoc
const mixin HttpStatusPageDefault : HttpStatusProcessor { }

internal const class HttpStatusPageDefaultImpl : HttpStatusPageDefault {

	@Inject private const BedSheetPage 	bedSheetPage
	@Inject	private const HttpResponse 	response

	internal new make(|This|in) { in(this) }

	override Text process(HttpStatus httpStatus) {
		if (!response.isCommitted)	// a sanity check
			response.statusCode = httpStatus.code

		title	:= "${httpStatus.code} - " + WebRes.statusMsg[httpStatus.code]
		// if the msg is html, leave it as is
		content	:= httpStatus.msg.startsWith("<p>") ? httpStatus.msg : "<p><b>${httpStatus.msg}</b></p>"
		return bedSheetPage.render(title, content)
	}	
}
