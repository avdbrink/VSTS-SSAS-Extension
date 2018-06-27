Installeer NodeJS op je ontiwkkel machine:
	https://nodejs.org/en/
	
Installeer de tfx-cli tool op je computer:

	npm i -g tfx-cli

	
Gebruik vervolgens onderstaande instuctie vanuit een command prompt om het package te maken:

	tfx extension create --manifest-globs vss-extension.json

	NB: Voor je een niuewe versie maakt moet je het versienummer in de files vss-extension.json en DeploySSASTask\task.json met 1 ophogen. 
	Als dat niet gebeurt zal TFS het component op de agents niet automatisch vervangen.