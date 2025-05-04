/**
 * Convert hub URLs in a UCSC hub text file to absolute URLs
 */


import fs from 'fs'

(async function () {
    await toAbsolute('https://hgdownload.soe.ucsc.edu/hubs/GCF/002/263/795/GCF_002263795.1/hub.txt', 'bosTau9.hub.txt')
})()

async function toAbsolute(hubURL, outputFile) {

    const idx = hubURL.lastIndexOf("/")
    const baseURL = hubURL.substring(0, idx + 1)

    const urlProperties = new Set(["descriptionUrl", "desriptionUrl",
        "twoBitPath", "blat", "chromAliasBb", "twoBitBptURL", "twoBitBptUrl", "htmlPath", "bigDataUrl",
        "genomesFile", "trackDb", "groups", "include", "html", "searchTrix", "linkDataUrl", "chromSizes"])

    // Fetch hub text
    const response = await fetch(hubURL)
    if (!response.ok) {
        throw new Error(`Response status: ${response.status}`)
    }
    const text = await response.text()

    const lines = text.split('\n')

    const out = fs.createWriteStream(outputFile, {flags: 'w'})

    for (let line of lines) {

        const indent = indentLevel(line)
        const i = line.indexOf(' ', indent)
        if (i < 0 || line.trim().startsWith('#')) {
            out.write(line)
            out.write('\n')
            continue
        }

        const key = line.substring(indent, i).trim()
        if (urlProperties.has(key)) {
            const value = line.substring(i + 1).trim()
            out.write(' '.repeat(indent))
            out.write(`${key} ${baseURL}${value}`)
        } else {
            out.write(line)
        }
        out.write('\n')
    }

}

function firstWord(str) {
    const idx = str.indexOf(' ')
    return idx > 0 ? str.substring(0, idx) : str
}

function indentLevel(str) {
    let level = 0
    for (level = 0; level < str.length; level++) {
        const c = str.charAt(level)
        if (c !== ' ' && c !== '\t') break
    }
    return level
}