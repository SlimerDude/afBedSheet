
class RouteTree {

	private Str:Obj			handlers
	private Str:RouteTree	childTrees
	
	new make() {
		handlers	= Str:Obj[:]
		childTrees	= Str:RouteTree[:]
	}
	
	@Operator
	This set(Str[] segments, Obj handler) {
		depth	:= segments.size
		urlKey	:= segments.first.lower

		if (depth == 1) {
			handlers[urlKey] = handler

		} else {
			childTree := childTrees[urlKey]
			if (childTree == null)
				childTrees[urlKey] = childTree = RouteTree()
			childTree[segments[1..-1]] = handler
		}

		return this
	}

	@Operator
	internal Route3? get(Str[] segments) {
		depth	:= segments.size
		segment	:= segments.first
		urlKey	:= segment.lower

		if (depth == 1) {

			handler := handlers[urlKey]
			if (handler != null) {
				route := Route3(handler)
				route.canonical.insert(0, urlKey)
				return route
			}

			handler = handlers["*"]
			if (handler != null) {
				route := Route3(handler)
				route.canonical.insert(0, urlKey)
				route.wildcards.insert(0, segment)
				return route
			}

		} else {

			childTree := childTrees[urlKey]
			if (childTree != null) {
				route := childTree[segments[1..-1]]
				if (route != null) {
					route.canonical.insert(0, urlKey)
				}
				return route
			}

			childTree = childTrees["*"]
			if (childTree != null) {
				route := childTree[segments[1..-1]]
				if (route != null) {
					route.canonical.insert(0, urlKey)
					route.wildcards.insert(0, segment)
				}
				return route
			}
		}

		handler := handlers["**"]
		if (handler != null) {
			route := Route3(handler)
			for (i := 0; i < segments.size; ++i) {
				route.canonical.add(segments[i].lower)
			}
			route.remaining = segments
			return route
		}

		return null
    }
}
