# YellowNote Design Notes

A full macOS GUI app in a single file, with no Xcode project. The entire thing is `main.swift` -- no storyboards, no Info.plist, no `.xcodeproj`. It bootstraps `NSApplication` manually, sets up the menu bar, and runs the event loop directly.

## Classic Mac OS System 7 Window

Rather than using native macOS window chrome, it uses a `borderless` `NSWindow` and hand-draws everything:

The title bar has horizontal black pinstripes that break around the close box and the centered window title, exactly like System 7 did.

The close box is the little square in the top-left that shows an X when clicked, replacing the modern macOS traffic light buttons.

The Chicago font (`ChicagoFLF.ttf`) is loaded from disk and registered at runtime with `CTFontManagerRegisterFontsForURL`. Chicago was the System 7 UI font.

A custom resize handle draws diagonal grip lines in the bottom-right corner, with drag-to-resize logic.

The title bar color (`#ACECBA`) gives it a slight green/yellow sticky note tint rather than the original gray, fitting the "YellowNote" name.

Window dragging is done via `performDrag(with:)` on the title bar's `mouseDown`, which is the clean low-level way to make a borderless window draggable.

Everything is raw AppKit drawing, with no dependencies beyond Cocoa.
