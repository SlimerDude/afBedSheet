using web

internal class TestFileHandling : AppTest {
	File	file1	:= `test/app-web/mr-file.txt`.toFile
	File	file2	:= `test/app-web/name with spaces.txt`.toFile
	
	** See `https://en.wikipedia.org/wiki/Directory_traversal_attack`
	Void testPathTraversalAttacks() {
		
		// This is mainly handled by Wisp that normalises URIs
		client.reqUri = reqUri(`/test-src/../../build.fan`) 
		client.writeReq.readRes
		res := client.resIn.readAllStr.trim
		verifyEq(client.resCode, 400, "$client.resCode - $client.resPhrase")
		
		client = WebClient()
		verifyStatus(`/test-src/../Example.fan`, 404)

		client = WebClient()
		verifyStatus(`/test-src/%2e%2e%2f%2e%2e%2fbuild.fan`, 404)
	}

	Void testFileIsServed() {
		text := getAsStr(`/test-src/mr-file.txt`)

		verifyEq(text, "In da house!")
		verifyEq(client.resHeaders["ETag"], etag(file1))
//		verifyEq(client.resHeaders["Cache-Control"], "public")
		verifyNull(client.resHeaders["Cache-Control"])
		verifyLastModified(file1.modified)
	}
	
	Void testHeadRequest() {
		text := getAsStr(`/test-src/mr-file.txt`, "HEAD")

		verifyEq(client.resHeaders["ETag"], etag(file1))
		verifyEq(client.resHeaders["Content-Length"], "12")
//		verifyEq(client.resHeaders["Cache-Control"], "public")
		verifyNull(client.resHeaders["Cache-Control"])
		verifyLastModified(file1.modified)
		verifyEq(text, "")
	}

	Void testSpaceFileIsServed() {
		text := getAsStr(`/test-src/name with spaces.txt`)

		verifyEq(text, "Spaces I got!")
		verifyEq(client.resHeaders["ETag"], etag(file2))
//		verifyEq(client.resHeaders["Cache-Control"], "public")
		verifyNull(client.resHeaders["Cache-Control"])
		verifyLastModified(file2.modified)
	}

	Void testQueryParamsAreIgnored() {
		text := getAsStr(`/test-src/mr-file.txt?wotever`)
		verifyEq(text, "In da house!")

		client	= WebClient()
		text 	= getAsStr(`/test-src/mr-file.txt?wot&ever`)
		verifyEq(text, "In da house!")
	}

	Void test404() {
		verify404(`/test-src/gazumped,txt`)
	}

	Void testFolderNonSlash() {
		// this directly returns a File object
		verifyStatus(`fh/test-src/folder`, 404)
		
		// this returns a FileAsset object via FileHandler
		client = WebClient()
		verifyStatus(`/test-src/folder`, 404)
	}

	Void testFolder() {
		// this directly returns a File object
		verifyStatus(`fh/test-src/folder/`, 404)
		
		// this returns a FileAsset object via FileHandler
		client = WebClient()
		verifyStatus(`/test-src/folder/`, 404)
	}

	Void testSillyUser() {
		verifyStatus(`/test-src2/folder/`, 404)
	}

	Void testMatchingEtagGives304() {
		client.reqHeaders["If-None-Match"] = etag(file1)
		
		verifyStatus(`/test-src/mr-file.txt`, 304)
		verifyEq(client.resHeaders["ETag"], etag(file1))
		verifyLastModified(file1.modified)
		verifyEq(client.resIn.readAllStr, "")
	}

	Void testNewLastModifiedGives304() {
		client.reqHeaders["If-Modified-Since"] = (file1.modified + 1hr).toHttpStr
		
		verifyStatus(`/test-src/mr-file.txt`, 304)
		verifyEq(client.resHeaders["ETag"], etag(file1))
		verifyLastModified(file1.modified)
		verifyEq(client.resIn.readAllStr, "")
	}

	Void testOldLastModifiedSendsFile() {
		client.reqHeaders["If-Modified-Since"] = (file1.modified - 1hr).toHttpStr
		text := getAsStr(`/test-src/mr-file.txt`)
		
		verifyEq(text, "In da house!")
		verifyEq(client.resHeaders["ETag"], etag(file1))
		verifyLastModified(file1.modified)
	}

	Void testFileDeletion() {
		// test what happens if a file is deleted while it still exists in the FileMetaCache
		killMe := `test/app-web/kill-me.txt`.toFile.deleteOnExit
		killMe.out.print("Spoolge!").flush.close
		text := getAsStr(`/test-src/kill-me.txt`)
		
		verifyEq(text, "Spoolge!")
		killMe.delete
		concurrent::Actor.sleep(1sec)	// default dev timeout for FileMetaCache is 2 sec
		
		client = WebClient()
		verify404(`/test-src/kill-me.txt`)

		client = WebClient()	// one more time for good measure!
		verify404(`/test-src/kill-me.txt`)
	}
	
	private Str etag(File file) {
		"\"${file.size.toHex}-${file.modified.floor(1sec).ticks.toHex}\""
	}
}
