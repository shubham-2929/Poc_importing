def doPost(request, session):
  try:
        tags_file = "C:/Program Files/Inductive Automation/Ignition/data/config/resources/core/ignition/tag-definition/default/tags.json"

        tags_json = system.file.readFileAsString(tags_file)

        system.tag.configure("[default]", tags_json, 'o')

        return {"json": {"status": "success"}}
  except Exception as e:
  		
	    return {"json": {"status": "error", "message": str(e)}}

        

 
