import SwiftUI
import UIKit

struct ScriptEditorView: View {
    @Binding var text: String
    var onCommit: () -> Void
    var errorMessage: String?
    var jumpToLine: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Script Editor")
                    .font(.headline)
                Spacer()

                if let error = errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: onCommit) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.green)
                }
                .accessibilityIdentifier("script_run_button")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            HighlightedTextEditor(
                text: $text,
                errorMessage: errorMessage,
                jumpToLine: jumpToLine
            )
            .accessibilityIdentifier("script_editor_view")
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - UITextView Wrapper with Syntax Highlighting

struct HighlightedTextEditor: UIViewRepresentable {
    @Binding var text: String
    var errorMessage: String?
    var jumpToLine: Int?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .systemBackground

        let containerView = UIView()
        scrollView.addSubview(containerView)

        // Line number gutter
        let gutterView = LineNumberGutterView()
        gutterView.tag = 100
        containerView.addSubview(gutterView)

        // Text view
        let textView = UITextView()
        textView.tag = 200
        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardType = .asciiCapable
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 8)
        containerView.addSubview(textView)

        // Error banner (at bottom of gutter area)
        let errorLabel = UILabel()
        errorLabel.tag = 300
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 2
        errorLabel.isHidden = true
        containerView.addSubview(errorLabel)

        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = containerView
        context.coordinator.textView = textView
        context.coordinator.gutterView = gutterView
        context.coordinator.errorLabel = errorLabel

        // Apply initial content
        context.coordinator.applyHighlighting(text)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        if textView.text != text {
            let selectedRange = textView.selectedRange
            context.coordinator.applyHighlighting(text)
            // Restore cursor position
            if selectedRange.location <= text.count {
                textView.selectedRange = selectedRange
            }
        }

        // Update error display
        if let error = errorMessage {
            context.coordinator.errorLabel?.text = error
            context.coordinator.errorLabel?.isHidden = false
        } else {
            context.coordinator.errorLabel?.isHidden = true
        }

        // Jump to line
        if let line = jumpToLine, line > 0 {
            context.coordinator.scrollToLine(line)
        }

        context.coordinator.layoutViews()
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightedTextEditor
        weak var scrollView: UIScrollView?
        weak var containerView: UIView?
        weak var textView: UITextView?
        weak var gutterView: LineNumberGutterView?
        weak var errorLabel: UILabel?

        private var isUpdating = false

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            parent.text = textView.text

            // Re-highlight
            isUpdating = true
            let selectedRange = textView.selectedRange
            applyHighlighting(textView.text)
            textView.selectedRange = selectedRange
            isUpdating = false

            layoutViews()
        }

        func applyHighlighting(_ source: String) {
            guard let textView = textView else { return }
            let attributed = SyntaxHighlighter.highlight(source)
            textView.attributedText = attributed

            gutterView?.lineCount = source.components(separatedBy: "\n").count
            gutterView?.setNeedsDisplay()
        }

        func scrollToLine(_ line: Int) {
            guard let textView = textView else { return }
            let lines = textView.text.components(separatedBy: "\n")
            guard line > 0, line <= lines.count else { return }

            var offset = 0
            for i in 0..<(line - 1) {
                offset += lines[i].count + 1
            }

            let range = NSRange(location: min(offset, textView.text.count), length: 0)
            textView.selectedRange = range
            textView.scrollRangeToVisible(range)
        }

        func layoutViews() {
            guard let scrollView = scrollView,
                  let containerView = containerView,
                  let textView = textView,
                  let gutterView = gutterView,
                  let errorLabel = errorLabel else { return }

            let gutterWidth: CGFloat = 40
            let width = scrollView.bounds.width
            let height = max(textView.contentSize.height + 40, scrollView.bounds.height)

            containerView.frame = CGRect(x: 0, y: 0, width: width, height: height)
            gutterView.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: height)
            textView.frame = CGRect(x: gutterWidth, y: 0, width: width - gutterWidth, height: height)

            if !errorLabel.isHidden {
                errorLabel.frame = CGRect(x: gutterWidth + 8, y: height - 36, width: width - gutterWidth - 16, height: 32)
            }

            scrollView.contentSize = CGSize(width: width, height: height)
        }
    }
}

// MARK: - Line Number Gutter

class LineNumberGutterView: UIView {
    var lineCount: Int = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemGroupedBackground.withAlphaComponent(0.5)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let lineHeight: CGFloat = 20.0 // approximate
        let topInset: CGFloat = 8.0

        for i in 0..<lineCount {
            let y = topInset + CGFloat(i) * lineHeight
            if y > rect.maxY { break }
            if y + lineHeight < rect.minY { continue }

            let text = "\(i + 1)" as NSString
            let size = text.size(withAttributes: attributes)
            let x = bounds.width - size.width - 4
            text.draw(at: CGPoint(x: max(x, 2), y: y), withAttributes: attributes)
        }
    }
}
