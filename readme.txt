How To build:

Composing VSTS tasks uses the TFX-CLI package to make the .vsix file.
To use tfx-cli you need NodeJS: https://nodejs.org/en/

Install the tfx-cli package: npm i -g tfx-cli
(see https://github.com/Microsoft/tfs-cli)

To build the vsix package use the instruction: 

	tfx extension create --manifest-globs vss-extension.json

Before building from source you need to upgrade the version number in all json files. (vss-extension.json & <tasks>\task.json).
Not updating the version number will cuase VSTS agent to ignore your new component and not auto update
