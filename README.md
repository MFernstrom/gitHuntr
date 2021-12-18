# gitHuntr

Multi-platform GitHub search.

Find stuff in GitHub repos and all your branches

* Search filenames using regex
* Search in file contents using regex
* Entropy search - Similar to TruffleHog


## Options
-h                   Show this help

-f                   Regex to match filenames

-c                   Regex to match file content

-o                   File to write report json to

-r                   URL for repo to scan

-e                   Perform Entropy search (slow)


## Example
`gitHuntr -f .*test.* -c .*auth_token.* -o report.json -e -r https://github.com/MFernstrom/TwilioLib`


## Platforms
* Windows x64
* macOS x64
* Linux x64


## Version
This is an initial beta release to help find log4j issues in your repos
