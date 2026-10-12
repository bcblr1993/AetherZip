import AppKit
import Foundation
let out=URL(fileURLWithPath:CommandLine.arguments[1]);try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
for (name,size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
 let image=NSImage(size:NSSize(width:size,height:size));image.lockFocus();let s=CGFloat(size)
 let rect=NSRect(x:s*0.09,y:s*0.09,width:s*0.82,height:s*0.82)
 let tile=NSBezierPath(roundedRect:rect,xRadius:s*0.19,yRadius:s*0.19)
 NSGradient(starting:NSColor(calibratedRed:0.64,green:0.65,blue:0.95,alpha:1),ending:NSColor(calibratedRed:0.30,green:0.34,blue:0.73,alpha:1))!.draw(in:tile,angle:-60)
 NSColor.white.withAlphaComponent(0.4).setStroke();tile.lineWidth=s*0.008;tile.stroke()
 if let symbol=NSImage(systemSymbolName:"archivebox",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:s*0.47,weight:.ultraLight)) {
 let target=NSRect(x:s*0.255,y:s*0.27,width:s*0.49,height:s*0.45);symbol.draw(in:target);NSColor.white.setFill();target.fill(using:.sourceAtop)
 }
 image.unlockFocus();let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!;try rep.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent(name+".png"))
}
