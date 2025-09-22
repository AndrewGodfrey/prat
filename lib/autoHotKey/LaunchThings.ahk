#Requires AutoHotkey v2

launch_msdocSearch(query) {
    Run("https://www.google.com/search?hl=en&ie=UTF-8&oe=UTF-8&as_sitesearch=learn.microsoft.com&q=" . query . "&btnG=search")
}

launch_webSearch(query) {
    Run("https://www.google.com/search?hl=en&ie=UTF-8&oe=UTF-8&q=" . query . "&btnG=search")
}

launch_knowledgeBaseArticle(kbId) {
    launch_webSearch("KB" . kbId)
}

launch_ViewJson(jsonData) {
    fileName := EnvGet("temp") . "/ahk_launchThings_json_temp.json"
    if FileExist(fileName)
	    FileDelete(fileName)

    FileAppend(jsonData, fileName)
    findAndlaunch_fileInEditor(filename, 0)
}
