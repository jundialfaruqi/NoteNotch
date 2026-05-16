import SwiftUI
import AppKit
import Combine

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var rtfData: Data // Store as RTF data to keep styles
    var isPinned: Bool = false
    var createdAt = Date()
    
    // Helper to get plain text for search or preview
    var plainText: String {
        if let attrString = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            return attrString.string
        }
        return ""
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("notes_data") private var notesData: String = "[]"
    @State private var notes: [Note] = []
    
    // Editor states
    @State private var currentRTFData: Data = Data()
    @State private var isAddingNote = false
    @State private var isMinimized = false
    @State private var editingNoteID: UUID? = nil
    @StateObject private var proxy = EditorProxy()

    var body: some View {
        ZStack(alignment: .top) {
            // Area Pemicu (Trigger Zone) yang selalu aktif di bagian atas Notch
            Color.white.opacity(0.001)
                .frame(width: 200, height: 30)
                .onHover { hovering in
                    if hovering && isMinimized {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isMinimized = false
                        }
                    }
                }
                .zIndex(100)

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text("NoteNotch")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading, 8)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            if isAddingNote {
                                cancelEditing()
                            } else {
                                isAddingNote = true
                            }
                        }
                    }) {
                        Image(systemName: isAddingNote ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isAddingNote ? .red.opacity(0.7) : .blue)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isMinimized = true
                        }
                    }) {
                        Image(systemName: "minus.square")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 10)
                    
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "power")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 15)

                if isAddingNote {
                    editorView
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    tabsAndContent
                }
            }
            .opacity(isMinimized ? 0 : 1)
            .offset(y: isMinimized ? -100 : 10) // <-- PENGATUR JARAK APUNG: Ganti '0' untuk menjauhkan/mendekatkan dari pinggir atas layar
        }
        .frame(width: 400)
        .frame(height: isMinimized ? 30 : (isAddingNote ? 500 : 500), alignment: .top)
        .background(
            ZStack {
                Color.black.opacity(isMinimized ? 0 : 0.85)
                if !isMinimized {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(isMinimized ? 0 : 0.1), lineWidth: 1)
        )
        .onAppear(perform: loadNotes)
        .onChange(of: notes) {
            saveNotes()
        }
    }

    private var tabsAndContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TabButton(title: "Pinned", icon: "pin.fill", isSelected: selectedTab == 0) {
                    withAnimation(.spring()) { selectedTab = 0 }
                }
                TabButton(title: "Notes", icon: "note.text", isSelected: selectedTab == 1) {
                    withAnimation(.spring()) { selectedTab = 1 }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 15)

            ZStack {
                if selectedTab == 0 {
                    pinnedListView
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    allNotesView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var editorView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ToolbarIcon(icon: "bold", isActive: proxy.isBold, tooltip: "Bold (Cmd+B)") { proxy.toggleBold() }
                    .keyboardShortcut("b", modifiers: .command)
                ToolbarIcon(icon: "italic", isActive: proxy.isItalic, tooltip: "Italic (Cmd+I)") { proxy.toggleItalic() }
                    .keyboardShortcut("i", modifiers: .command)
                ToolbarIcon(icon: "underline", isActive: proxy.isUnderline, tooltip: "Underline (Cmd+U)") { proxy.toggleUnderline() }
                    .keyboardShortcut("u", modifiers: .command)
                ToolbarIcon(icon: "list.bullet", isActive: false, tooltip: "Bullet List (Cmd+L)") { proxy.toggleList() }
                    .keyboardShortcut("l", modifiers: .command)
                ToolbarIcon(icon: "list.number", isActive: false, tooltip: "Ordered List (Cmd+Shift+L)") { proxy.toggleOrderedList() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                ToolbarIcon(icon: "curlybraces", isActive: proxy.isCodeSnippet, tooltip: "Code Snippet (Cmd+J)") { proxy.toggleCodeSnippet() }
                    .keyboardShortcut("j", modifiers: .command)
                
                ColorPickerButton(proxy: proxy)
                
                Spacer()
                
                Button(editingNoteID != nil ? "Update" : "Save") {
                    saveNote()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            
            MacRichEditorView(rtfData: $currentRTFData, proxy: proxy)
                .frame(height: 365)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.05).cornerRadius(12).padding(.horizontal, 20))
            
            Spacer()
        }
        .padding(.top, 5)
    }

    private var pinnedListView: some View {
        VStack {
            let pinned = notes.filter { $0.isPinned }
            if pinned.isEmpty {
                emptyStateView(icon: "pin.slash", message: "No pinned notes")
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(pinned) { note in
                            NoteRow(note: note, isPinnedTab: true, onTogglePin: { togglePin(note) }, onDelete: { deleteNote(note) }, onEdit: { editNote(note) })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var allNotesView: some View {
        VStack(spacing: 15) {
            if notes.isEmpty {
                emptyStateView(icon: "note.text", message: "Start by adding a note")
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                            NoteRow(note: note, isPinnedTab: false, onTogglePin: { togglePin(note) }, onDelete: { deleteNote(note) }, onEdit: { editNote(note) })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.2))
            Text(message)
                .foregroundColor(.white.opacity(0.4))
                .font(.system(size: 14))
            Spacer()
        }
    }

    private func editNote(_ note: Note) {
        currentRTFData = note.rtfData
        editingNoteID = note.id
        withAnimation(.spring()) {
            isAddingNote = true
        }
    }

    private func cancelEditing() {
        isAddingNote = false
        editingNoteID = nil
        currentRTFData = Data()
    }

    private func saveNote() {
        guard !currentRTFData.isEmpty else { return }
        
        withAnimation(.spring()) {
            if let id = editingNoteID, let index = notes.firstIndex(where: { $0.id == id }) {
                // Update existing
                notes[index].rtfData = currentRTFData
            } else {
                // Create new
                let newNote = Note(rtfData: currentRTFData)
                notes.append(newNote)
            }
            cancelEditing()
        }
    }

    private func togglePin(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            withAnimation(.spring()) {
                notes[index].isPinned.toggle()
            }
        }
    }

    private func deleteNote(_ note: Note) {
        withAnimation(.spring()) {
            notes.removeAll(where: { $0.id == note.id })
        }
    }

    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            notesData = String(data: encoded, encoding: .utf8) ?? "[]"
        }
    }

    private func loadNotes() {
        if let data = notesData.data(using: .utf8) {
            if let decoded = try? JSONDecoder().decode([Note].self, from: data) {
                notes = decoded
            }
        }
    }
}

struct NoteRow: View {
    let note: Note
    let isPinnedTab: Bool
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                RichTextSplitPreview(rtfData: note.rtfData, showFullContent: isPinnedTab)
                
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit()
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onTogglePin) {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .foregroundColor(note.isPinned ? .orange : .white.opacity(0.4))
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isHovering ? 0.1 : 0.05))
                .animation(.easeInOut(duration: 0.2), value: isHovering)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isHovering ? 0.2 : 0.05), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Rich Text Editor Logic
class EditorProxy: ObservableObject {
    var textView: NSTextView?
    @Published var isBold: Bool = false
    @Published var isItalic: Bool = false
    @Published var isUnderline: Bool = false
    @Published var isCodeSnippet: Bool = false
    @Published var selectedColor: Color = .white
    
    func updateState() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        let fullString = textView.string as NSString
        
        let firstLineEnd = fullString.range(of: "\n").location
        let isCursorInTitle = (firstLineEnd == NSNotFound) || (range.location <= firstLineEnd)
        
        let newIsBold: Bool
        let newIsItalic: Bool
        let newIsUnderline: Bool
        
        if isCursorInTitle {
            newIsBold = false
            newIsItalic = false
            newIsUnderline = false
        } else {
            // Cek Gaya Font (Bold & Italic)
            if let font = textView.typingAttributes[.font] as? NSFont {
                let traits = NSFontManager.shared.traits(of: font)
                newIsBold = traits.contains(.boldFontMask)
                newIsItalic = traits.contains(.italicFontMask)
            } else {
                newIsBold = false
                newIsItalic = false
            }
            
            // Cek Underline
            if let underline = textView.typingAttributes[.underlineStyle] as? Int {
                newIsUnderline = underline != 0
            } else {
                newIsUnderline = false
            }
        }
        
        let newSelectedColor: Color
        if let color = textView.typingAttributes[.foregroundColor] as? NSColor {
            newSelectedColor = Color(color)
        } else {
            newSelectedColor = .white
        }
        
        var newIsCodeSnippet = false
        if let font = textView.typingAttributes[.font] as? NSFont {
            newIsCodeSnippet = font.fontName.contains("Mono") || font.fontName.contains("Menlo")
        }
        
        // Bungkus dalam async agar tidak bentrok dengan update view
        DispatchQueue.main.async {
            self.isBold = newIsBold
            self.isItalic = newIsItalic
            self.isUnderline = newIsUnderline
            self.isCodeSnippet = newIsCodeSnippet
            self.selectedColor = newSelectedColor
        }
    }
    
    func toggleBold() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        let fullString = textView.string as NSString
        let firstLineEnd = fullString.range(of: "\n").location
        
        // Blokir jika di judul
        if (firstLineEnd == NSNotFound) || (range.location <= firstLineEnd) { return }
        
        if range.length > 0 {
            let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            if NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                textView.textStorage?.applyFontTraits(.unboldFontMask, range: range)
            } else {
                textView.textStorage?.applyFontTraits(.boldFontMask, range: range)
            }
        } else {
            // Toggle untuk ketikan selanjutnya
            var attrs = textView.typingAttributes
            if let font = attrs[.font] as? NSFont {
                let newFont: NSFont
                if NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                    newFont = NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
                attrs[.font] = newFont
                textView.typingAttributes = attrs
            }
        }
        textView.didChangeText() // Paksa simpan agar shortcut tersimpan
        updateState()
    }
    
    func toggleItalic() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        let fullString = textView.string as NSString
        let firstLineEnd = fullString.range(of: "\n").location
        
        if (firstLineEnd == NSNotFound) || (range.location <= firstLineEnd) { return }
        
        if range.length > 0 {
            let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            if NSFontManager.shared.traits(of: font).contains(.italicFontMask) {
                textView.textStorage?.applyFontTraits(.unitalicFontMask, range: range)
            } else {
                textView.textStorage?.applyFontTraits(.italicFontMask, range: range)
            }
        } else {
            var attrs = textView.typingAttributes
            if let font = attrs[.font] as? NSFont {
                let newFont: NSFont
                if NSFontManager.shared.traits(of: font).contains(.italicFontMask) {
                    newFont = NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                attrs[.font] = newFont
                textView.typingAttributes = attrs
            }
        }
        textView.didChangeText()
        updateState()
    }
    
    func toggleUnderline() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        let fullString = textView.string as NSString
        let firstLineEnd = fullString.range(of: "\n").location
        
        // Blokir jika di judul
        if (firstLineEnd == NSNotFound) || (range.location <= firstLineEnd) { return }
        
        if range.length > 0 {
            let currentUnderline = textView.typingAttributes[.underlineStyle] as? Int ?? 0
            if currentUnderline == 0 {
                textView.textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                textView.textStorage?.removeAttribute(.underlineStyle, range: range)
            }
        } else {
            // Toggle untuk ketikan selanjutnya
            var attrs = textView.typingAttributes
            let currentUnderline = attrs[.underlineStyle] as? Int ?? 0
            attrs[.underlineStyle] = (currentUnderline == 0) ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes = attrs
        }
        textView.didChangeText() // Paksa simpan agar shortcut tersimpan
        updateState()
    }
    
    func toggleList() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        let fullString = textView.string as NSString
        let firstLineEnd = fullString.range(of: "\n").location
        
        // Blokir jika di judul
        if (firstLineEnd == NSNotFound) || (range.location <= firstLineEnd) { return }
        
        if range.length == 0 {
            let lineRange = fullString.lineRange(for: NSRange(location: range.location, length: 0))
            let currentLine = fullString.substring(with: lineRange)
            
            if currentLine.hasPrefix("•\t") {
                // Hapus bullet dan kembalikan indentasi ke normal
                let bulletRange = NSRange(location: lineRange.location, length: 2)
                textView.insertText("", replacementRange: bulletRange)
                
                let normalStyle = NSMutableParagraphStyle()
                normalStyle.lineSpacing = 4
                textView.textStorage?.addAttribute(.paragraphStyle, value: normalStyle, range: lineRange)
            } else {
                // Tambah bullet dengan Tab dan Indentasi
                textView.insertText("•\t", replacementRange: NSRange(location: lineRange.location, length: 0))
                
                // Ambil ulang jangkauan baris yang sudah diperbarui
                let updatedFullString = (textView.string as NSString)
                let newLineRange = updatedFullString.lineRange(for: NSRange(location: lineRange.location, length: 2))
                
                let paraStyle = NSMutableParagraphStyle()
                let indent: CGFloat = 22
                paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
                paraStyle.headIndent = indent
                paraStyle.firstLineHeadIndent = 0
                paraStyle.lineSpacing = 4
                paraStyle.lineBreakMode = .byCharWrapping
                textView.textStorage?.addAttribute(.paragraphStyle, value: paraStyle, range: newLineRange)
            }
        } else {
            // KASUS: Ada seleksi teks
            let selectedText = fullString.substring(with: range)
            let lines = selectedText.components(separatedBy: "\n")
            
            let shouldAdd = !lines.contains { $0.hasPrefix("•\t") }
            
            let listLines = lines.map { line -> String in
                if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
                if shouldAdd {
                    return line.hasPrefix("•\t") ? line : "•\t" + line
                } else {
                    return line.hasPrefix("•\t") ? String(line.dropFirst(2)) : line
                }
            }
            let newListText = listLines.joined(separator: "\n")
            textView.insertText(newListText, replacementRange: range)
            
            let paraStyle = NSMutableParagraphStyle()
            let indent: CGFloat = 22
            paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
            paraStyle.headIndent = indent
            paraStyle.firstLineHeadIndent = 0
            paraStyle.lineSpacing = 4
            paraStyle.lineBreakMode = .byCharWrapping // Potong karakter jika kata terlalu panjang
            
            let updatedLineRange = (textView.string as NSString).lineRange(for: range)
            textView.textStorage?.addAttribute(.paragraphStyle, value: paraStyle, range: updatedLineRange)
        }
        textView.didChangeText() // Paksa simpan agar shortcut tersimpan
        updateState()
    }
    
    func toggleCodeSnippet() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        let fullString = textView.string as NSString
        let firstLineEnd = fullString.range(of: "\n").location
        
        // Blokir jika di judul
        if (firstLineEnd == NSNotFound) || (range.location <= firstLineEnd) { return }
        
        let storage = textView.textStorage
        // Luaskan jangkauan ke seluruh baris agar blok kodenya rapi
        let lineRange = fullString.lineRange(for: range)
        
        if isCodeSnippet {
            // Revert ke gaya normal
            let normalFont = NSFont.systemFont(ofSize: 14)
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.lineSpacing = 4
            // Atur jarak tab agar tidak terlalu jauh (20 poin)
            paraStyle.defaultTabInterval = 20
            paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: 20, options: [:])]
            
            storage?.addAttribute(.font, value: normalFont, range: lineRange)
            storage?.addAttribute(.paragraphStyle, value: paraStyle, range: lineRange)
            storage?.removeAttribute(.backgroundColor, range: lineRange)
        } else {
            // Terapkan Gaya Blok Kode (Hanya Font Monospaced)
            let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            
            // Terapkan ke seluruh jangkauan baris
            storage?.addAttribute(.font, value: codeFont, range: lineRange)
            
            // Berikan spasi baris agar blok kode terlihat lega
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.lineSpacing = 6
            // Samakan tab interval agar konsisten
            paraStyle.defaultTabInterval = 20
            storage?.addAttribute(.paragraphStyle, value: paraStyle, range: lineRange)
        }
        
        textView.didChangeText()
        updateState()
    }
    
    func toggleOrderedList() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        let fullString = textView.string as NSString
        let firstLineEnd = fullString.range(of: "\n").location
        
        if (firstLineEnd == NSNotFound) || (range.location <= firstLineEnd) { return }
        
        if range.length == 0 {
            let lineRange = fullString.lineRange(for: NSRange(location: range.location, length: 0))
            let currentLine = fullString.substring(with: lineRange)
            
            let regex = try? NSRegularExpression(pattern: "^\\d+\\.[\t ]", options: [])
            if let match = regex?.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: (currentLine as NSString).length)) {
                textView.insertText("", replacementRange: NSRange(location: lineRange.location, length: match.range.length))
                
                let normalStyle = NSMutableParagraphStyle()
                normalStyle.lineSpacing = 4
                textView.textStorage?.addAttribute(.paragraphStyle, value: normalStyle, range: lineRange)
            } else {
                textView.insertText("1.\t", replacementRange: NSRange(location: lineRange.location, length: 0))
                
                // RE-CALCULATE RANGE setelah insert
                let updatedFullString = (textView.string as NSString)
                let newLineRange = updatedFullString.lineRange(for: NSRange(location: lineRange.location, length: 3))
                
                let paraStyle = NSMutableParagraphStyle()
                let indent: CGFloat = 22
                paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
                paraStyle.headIndent = indent
                paraStyle.firstLineHeadIndent = 0
                paraStyle.lineSpacing = 4
                paraStyle.lineBreakMode = .byCharWrapping
                textView.textStorage?.addAttribute(.paragraphStyle, value: paraStyle, range: newLineRange)
            }
        } else {
            let selectedText = fullString.substring(with: range)
            let lines = selectedText.components(separatedBy: "\n")
            
            let regex = try? NSRegularExpression(pattern: "^\\d+\\. ", options: [])
            let shouldAdd = lines.first(where: { !($0.trimmingCharacters(in: .whitespaces).isEmpty) })
                .map { line in regex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: (line as NSString).length)) == nil } ?? true
            
            var counter = 1
            let listLines = lines.map { line -> String in
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return line }
                
                let nsLine = line as NSString
                if let match = regex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                    let textWithoutNumber = nsLine.substring(from: match.range.length)
                    if shouldAdd {
                        let newLine = "\(counter).\t\(textWithoutNumber)"
                        counter += 1
                        return newLine
                    } else {
                        return textWithoutNumber
                    }
                } else {
                    if shouldAdd {
                        let newLine = "\(counter).\t\(line)"
                        counter += 1
                        return newLine
                    } else {
                        return line
                    }
                }
            }
            let newListText = listLines.joined(separator: "\n")
            textView.insertText(newListText, replacementRange: range)
            
            // TERAPKAN GAYA INDENTASI PRO UNTUK SEMUA BARIS YANG DIPILIH
            let paraStyle = NSMutableParagraphStyle()
            let indent: CGFloat = 22
            paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
            paraStyle.headIndent = indent // Untuk baris baru jika teks panjang (wrap)
            paraStyle.firstLineHeadIndent = 0
            paraStyle.lineSpacing = 4
            paraStyle.lineBreakMode = .byCharWrapping // Potong karakter agar tidak turun semua
            
            let updatedLineRange = (textView.string as NSString).lineRange(for: range)
            textView.textStorage?.addAttribute(.paragraphStyle, value: paraStyle, range: updatedLineRange)
            
            // Pastikan gaya ini terbawa saat mengetik selanjutnya
            var attrs = textView.typingAttributes
            attrs[.paragraphStyle] = paraStyle
            textView.typingAttributes = attrs
        }
        textView.didChangeText()
        updateState()
    }
    
    func changeColor(_ color: NSColor) {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        
        selectedColor = Color(color)
        
        if range.length > 0 {
            textView.textStorage?.addAttribute(.foregroundColor, value: color, range: range)
        } else {
            var attrs = textView.typingAttributes
            attrs[.foregroundColor] = color
            textView.typingAttributes = attrs
        }
        textView.didChangeText()
        updateState()
    }
}

struct MacRichEditorView: NSViewRepresentable {
    @Binding var rtfData: Data
    let proxy: EditorProxy
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticLinkDetectionEnabled = true
        
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.font = .systemFont(ofSize: 14)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 12, height: 12)
        
        scrollView.documentView = textView
        
        DispatchQueue.main.async {
            self.proxy.textView = textView
            self.proxy.updateState()
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if rtfData.isEmpty {
                if !textView.string.isEmpty { textView.string = "" }
            } else {
                let currentLength = textView.textStorage?.length ?? 0
                if currentLength == 0 {
                    if let attrString = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                        textView.textStorage?.setAttributedString(attrString)
                    }
                }
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacRichEditorView
        private var isProcessingEnter = false
        
        init(_ parent: MacRichEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            if let textStorage = textView.textStorage {
                let fullString = textStorage.string
                let firstLineEnd = (fullString as NSString).range(of: "\n").location
                
                let titleRange: NSRange
                if firstLineEnd != NSNotFound {
                    titleRange = NSRange(location: 0, length: firstLineEnd)
                    
                    // Reset gaya kursor jika BARU SAJA pindah ke area isi (mencegah warisan judul)
                    let cursorLocation = textView.selectedRange().location
                    let isAtStartOfBody = cursorLocation == firstLineEnd + 1
                    
                    if isAtStartOfBody && textStorage.length == firstLineEnd + 1 {
                        // Hanya reset jika baris isi masih kosong (baru tekan Enter dari judul)
                        let regularFont = NSFont.systemFont(ofSize: 14, weight: .regular)
                        var typingAttrs = textView.typingAttributes
                        typingAttrs[.font] = regularFont
                        typingAttrs[.paragraphStyle] = NSParagraphStyle.default
                        textView.typingAttributes = typingAttrs
                    }
                } else {
                    titleRange = NSRange(location: 0, length: textStorage.length)
                }
                
                // HANYA format bagian Judul agar Bold dan berjarak
                if titleRange.length > 0 {
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .bold), range: titleRange)
                    let style = NSMutableParagraphStyle()
                    style.paragraphSpacing = 15
                    textStorage.addAttribute(.paragraphStyle, value: style, range: titleRange)
                }
            }
            
            let range = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
            if let data = try? textView.textStorage?.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                self.parent.rtfData = data
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            parent.proxy.updateState()
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if isProcessingEnter { return true }
            guard let replacement = replacementString else { return true }
            
            let fullString = textView.string as NSString
            let lineRange = fullString.lineRange(for: NSRange(location: affectedCharRange.location, length: 0))
            let currentLine = fullString.substring(with: lineRange)
            
            // --- AUTO FORMAT SAAT MENGETIK SPASI ---
            if replacement == " " {
                // A. Deteksi "1. "
                let numRegex = try? NSRegularExpression(pattern: "^(\\d+)\\.$", options: [])
                if numRegex?.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: (currentLine as NSString).length)) != nil {
                    textView.insertText("\t", replacementRange: affectedCharRange)
                    let paraStyle = NSMutableParagraphStyle()
                    let indent: CGFloat = 22
                    paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
                    paraStyle.headIndent = indent
                    paraStyle.firstLineHeadIndent = 0
                    paraStyle.lineBreakMode = .byCharWrapping
                    textView.textStorage?.addAttribute(.paragraphStyle, value: paraStyle, range: lineRange)
                    return false
                }
                
                // B. Deteksi "- " atau "* " untuk jadi Bullet
                if currentLine == "-" || currentLine == "*" {
                    textView.insertText("•\t", replacementRange: lineRange)
                    let paraStyle = NSMutableParagraphStyle()
                    let indent: CGFloat = 22
                    paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
                    paraStyle.headIndent = indent
                    paraStyle.firstLineHeadIndent = 0
                    textView.textStorage?.addAttribute(.paragraphStyle, value: paraStyle, range: lineRange)
                    return false
                }
            }
            
            // --- LOGIKA TOMBOL ENTER ---
            if replacement == "\n" {
                // 1. Logika untuk DAFTAR BULLET (• )
                if currentLine.hasPrefix("•\t") {
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "•" {
                        let deleteRange = NSRange(location: lineRange.location, length: currentLine.count)
                        textView.insertText("", replacementRange: deleteRange)
                    } else {
                        textView.insertText("\n•\t", replacementRange: affectedCharRange)
                        
                        // Terapkan Gaya Indentasi Pro (22 poin)
                        let paraStyle = NSMutableParagraphStyle()
                        let indent: CGFloat = 22
                        paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
                        paraStyle.headIndent = indent
                        paraStyle.firstLineHeadIndent = 0
                        paraStyle.lineBreakMode = .byCharWrapping
                        
                        let newFullString = textView.string as NSString
                        let newLineRange = newFullString.lineRange(for: NSRange(location: affectedCharRange.location + 1, length: 0))
                        textView.textStorage?.addAttribute(.paragraphStyle, value: paraStyle, range: newLineRange)
                    }
                    parent.proxy.updateState()
                    return false
                }
                
                // 2. Logika untuk DAFTAR BERNUMOR (1. , 2. , dst)
                let regex = try? NSRegularExpression(pattern: "^(\\d+)\\.[\t ]", options: [])
                if let match = regex?.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: (currentLine as NSString).length)) {
                    let numberString = (currentLine as NSString).substring(with: match.range(at: 1))
                    if let currentNumber = Int(numberString) {
                        if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "\(currentNumber)." {
                            let deleteRange = NSRange(location: lineRange.location, length: currentLine.count)
                            textView.insertText("", replacementRange: deleteRange)
                        } else {
                            // Lanjutkan nomor berikutnya dengan Tab
                            textView.insertText("\n\(currentNumber + 1).\t", replacementRange: affectedCharRange)
                            
                            // Terapkan Gaya Indentasi Pro (22 poin)
                            let paraStyle = NSMutableParagraphStyle()
                            let indent: CGFloat = 22
                            paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
                            paraStyle.headIndent = indent
                            paraStyle.firstLineHeadIndent = 0
                            paraStyle.lineBreakMode = .byCharWrapping
                            
                            let newFullString = textView.string as NSString
                            let newLineRange = newFullString.lineRange(for: NSRange(location: affectedCharRange.location + 1, length: 0))
                            textView.textStorage?.addAttribute(.paragraphStyle, value: paraStyle, range: newLineRange)
                            
                            // Pastikan kursor di baris baru mengikuti gaya ini
                            var attrs = textView.typingAttributes
                            attrs[.paragraphStyle] = paraStyle
                            textView.typingAttributes = attrs
                        }
                        parent.proxy.updateState()
                        return false
                    }
                }
            }
            
            return true
        }
        
        // --- PAKSA PASTE SEBAGAI PLAIN TEXT ---
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSText.paste(_:)) {
                textView.pasteAsPlainText(nil)
                return true
            }
            return false
        }
    }
}

struct ToolbarIcon: View {
    let icon: String
    let isActive: Bool
    let tooltip: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isActive ? .blue : .white.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(isActive ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct ColorPickerButton: View {
    @ObservedObject var proxy: EditorProxy
    @State private var showColors = false
    
    let colors: [(Color, NSColor, String)] = [
        (.white, .white, "White"),
        (.red, .systemRed, "Red"),
        (.green, .systemGreen, "Green"),
        (.blue, .systemBlue, "Blue"),
        (.yellow, .systemYellow, "Yellow"),
        (.orange, .systemOrange, "Orange"),
        (.purple, .systemPurple, "Purple"),
        (.pink, .systemPink, "Pink")
    ]
    
    var body: some View {
        Button(action: { showColors.toggle() }) {
            Circle()
                .fill(proxy.selectedColor)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                .shadow(color: Color.black.opacity(0.2), radius: 2)
        }
        .buttonStyle(.plain)
        .help("Text Color")
        .popover(isPresented: $showColors, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Text Color")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 2)
                
                LazyVGrid(columns: [GridItem(.fixed(24)), GridItem(.fixed(24)), GridItem(.fixed(24)), GridItem(.fixed(24))], spacing: 10) {
                    ForEach(colors, id: \.2) { item in
                        Circle()
                            .fill(item.0)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(proxy.selectedColor == item.0 ? Color.blue : Color.white.opacity(0.2), lineWidth: 2)
                            )
                            .onTapGesture {
                                proxy.changeColor(item.1)
                                showColors = false
                            }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                    Text(title)
                }
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
                    .cornerRadius(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


struct RichTextSplitPreview: NSViewRepresentable {
    let rtfData: Data
    let showFullContent: Bool
    
    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(labelWithAttributedString: NSAttributedString())
        label.isEditable = false
        label.isSelectable = false
        label.maximumNumberOfLines = 0
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.backgroundColor = .clear
        label.isBordered = false
        label.alignment = .left
        
        // Memastikan label tidak memotong teks secara vertikal
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return label
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        guard let attrString = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else { return }
        
        let mutableAttr = NSMutableAttributedString(attributedString: attrString)
        let fullString = mutableAttr.string
        
        if !fullString.isEmpty {
            let nsString = fullString as NSString
            let firstLineRange = nsString.lineRange(for: NSRange(location: 0, length: 0))
            
            // 1. Proses JUDUL (Baris 1)
            var titleText = nsString.substring(with: firstLineRange).trimmingCharacters(in: .newlines)
            if titleText.count > 50 {
                titleText = String(titleText.prefix(50)) + "..."
            }
            let titleAttr = NSMutableAttributedString(string: titleText)
            titleAttr.addAttribute(.font, value: NSFont.systemFont(ofSize: 14, weight: .bold), range: NSRange(location: 0, length: (titleText as NSString).length))
            
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = 4 // Jarak kecil antara judul dan isi
            titleAttr.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: titleAttr.length))
            
            mutableAttr.setAttributedString(titleAttr)
            
            // 2. Proses ISI (Baris selanjutnya)
            if showFullContent {
                // Tampilan Pinned: Tampilkan SEMUA isi
                let bodyOffset = firstLineRange.location + firstLineRange.length
                if nsString.length > bodyOffset {
                    let bodyAttr = attrString.attributedSubstring(from: NSRange(location: bodyOffset, length: nsString.length - bodyOffset))
                    mutableAttr.append(NSAttributedString(string: "\n"))
                    mutableAttr.append(bodyAttr)
                }
            } else {
                // Tampilan Daftar Utama: Tampilkan hanya baris pertama isi (Maks 50 karakter)
                let bodyOffset = firstLineRange.location + firstLineRange.length
                if nsString.length > bodyOffset {
                    let remainingString = nsString.substring(from: bodyOffset) as NSString
                    let secondLineRange = remainingString.lineRange(for: NSRange(location: 0, length: 0))
                    var bodySnippet = remainingString.substring(with: secondLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !bodySnippet.isEmpty {
                        if bodySnippet.count > 50 {
                            bodySnippet = String(bodySnippet.prefix(50)) + "..."
                        }
                        let snippetAttr = NSMutableAttributedString(string: "\n" + bodySnippet)
                        snippetAttr.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: NSRange(location: 0, length: (snippetAttr.string as NSString).length))
                        snippetAttr.addAttribute(.foregroundColor, value: NSColor.white.withAlphaComponent(0.6), range: NSRange(location: 0, length: (snippetAttr.string as NSString).length))
                        mutableAttr.append(snippetAttr)
                    }
                }
            }
        }
        
        // Pastikan warna dasar teks putih
        mutableAttr.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: (mutableAttr.string as NSString).length))
        
        nsView.attributedStringValue = mutableAttr
        nsView.preferredMaxLayoutWidth = nsView.frame.width
        nsView.invalidateIntrinsicContentSize()
    }
}
