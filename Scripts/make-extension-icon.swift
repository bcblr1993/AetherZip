import AppKit
import Foundation
let output = URL(fileURLWithPath: "Resources/ExtensionAssets.xcassets/ActionIcon.imageset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let size = NSSize(width: 64, height: 64)
let icon = NSImage(size: size)
icon.lockFocus()
NSColor.black.set()
let image = NSImage(systemSymbolName: "archivebox", accessibilityDescription: nil)!
image.draw(in: NSRect(x: 8, y: 8, width: 48, height: 48))
icon.unlockFocus()
let bitmap = NSBitmapImageRep(data: icon.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("ActionIcon.png"))
try Data("""
{"images":[{"filename":"ActionIcon.png","idiom":"universal"}],"info":{"author":"xcode","version":1},"properties":{"template-rendering-intent":"template"}}
""".utf8).write(to: output.appendingPathComponent("Contents.json"))
