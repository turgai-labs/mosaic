/// How pieces side by side line up, down: along their tops, centres or bottoms.
public enum VerticalAlignment: String, Codable, Sendable, Equatable {
    /// Along their tops.
    case top
    /// On their centres.
    case center
    /// Along their bottoms.
    case bottom
}

/// How pieces one under another line up, across: along their leading edges, centres or trailing
/// edges.
public enum HorizontalAlignment: String, Codable, Sendable, Equatable {
    /// Along their leading edges.
    case leading
    /// On their centres.
    case center
    /// Along their trailing edges.
    case trailing
}

/// A picture's shape, width to height.
public enum AspectRatio: String, Codable, Sendable, Equatable {
    /// As the picture is.
    case original
    /// 1:1.
    case square
    /// 4:3, wider than high.
    case landscape
    /// 16:9, much wider than high.
    case wide
    /// 3:4, higher than wide.
    case portrait
}

/// How a picture fills its shape.
public enum ImageFit: String, Codable, Sendable, Equatable {
    /// All of it shows, inside the shape.
    case fit
    /// It covers the shape, cut at the edges.
    case fill
}

/// How words look: what they are among the rest.
public enum TextStyle: String, Codable, Sendable, Equatable {
    /// The title, largest.
    case title
    /// A heading over what follows.
    case heading
    /// Ordinary words.
    case body
    /// Small words beside something else.
    case caption
    /// Words that stand out among others.
    case emphasis
}

/// The colour of words: what they mean.
public enum TextColor: String, Codable, Sendable, Equatable {
    /// Ordinary words.
    case primary
    /// Words that matter less.
    case secondary
    /// Words to notice.
    case accent
    /// Something that went well.
    case positive
    /// Something to be careful of.
    case warning
    /// Something that went wrong.
    case negative
}

/// What a button does, as it looks.
public enum ButtonKind: String, Codable, Sendable, Equatable {
    /// An ordinary button.
    case normal
    /// The button most pressed, which stands out.
    case prominent
    /// A button that removes or ends something.
    case destructive
}
