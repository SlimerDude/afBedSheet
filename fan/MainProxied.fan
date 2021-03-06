using util::Arg
using util::Opt
using util::AbstractMain

@NoDoc
class MainProxied : AbstractMain {

	@Arg { help="A serialized BedSheetBuilder" } 
	private Str? builder

	override Int run() {
		bob	:= BedSheetBuilder.fromStringy(builder)
		prt := bob.options[BsConstants.meta_appPort]
		return bob.startWisp(prt, false)
	}
}
