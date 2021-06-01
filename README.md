# Jsum

Jsum is a JSON object-mapping framework that aims to replace Codable for JSON object mapping. It takes a lot of inspiration from [Mantle](https://github.com/Mantle/Mantle), if you've ever used it back in Objective-C land.

The name Jsum comes from the `JSON` enum it provides, and the fact that enums are sum types. JSON + sum = Jsum(?)

## Installation

This library is a Swift package, so add it to your `Package.swift` like so or add it to your Xcode project.

```swift
.package(url: "https://github.com/NSExceptional/Jsum.git", .branch("master"))
```

**Jsum is still in early development**, so there are no releases yet. I recommend sticking to `master` for now; I won't commit any broken code going forward until the first release.

## Motivation

Codable is often thought of as not being flexible enough. Many common problems with it are outlined in the replies to [this Swift Forums post](https://forums.swift.org/t/serialization-in-swift/46641). In my opinion, Codable requires you to give up its most valuable feature—synthesized initializers—too often, and this is why it feels so cumbersome to use.

Codable and `JSONDecoder` don't offer a lot of up-front decoding customization, and miss a lot of common use cases. All of these missed use cases mean you have to implement `init(decoder:)` and manually decode every single property for that type, even if you only needed to adjust a single property's behavior.

Let's look at a not-quite-worst-case example. Say we have a JSON payload like this that we want to decode into a `Post` struct:

```json
{
    "title": "my code won't compile",
    "author": "NoobMaster69",
    "score": "-5",
    "bookmarked": null,
    "link": "https://imagehost/i/ad9f8yw.png",
    "upvoted": 0,
    ..., // A dozen other properties
    "comment_count": 24
}
```

Say we want to make the following changes:

- We want `score` to be a number, not a string
- We want `bookmarked` and `upvoted` to be booleans
- There is a missing `body` key we want to be a non-optional string, even if it is missing or null

In a perfect world, this is all we should need to write:

```swift
struct Post: Decodable {
    let title: String
    let body: String = ""
    let link: URL
    let author: String
    let score: Int
    let upvoted: Bool
    let bookmarked: Bool
    // A dozen other unmodified properties
    ...
    let commentCount: Int
}
```

However, this won't work for a number of reasons. For starters, Swift takes `let` seriously: `body` will only ever be `""` once you assign it that initial value. `JSONDecoder` won't intelligently do conversions between numbers/bools and strings, either, so we have to do those by hand. Or numbers and bools, etc. Pretty much all it will do for us is handle snake case to camel case and the automatic decoding of other properties that are `Codable` and decode successfully with their input. We end up writing a ton of boilerplate:

```swift
struct Post: Decodable {
    let title: String
    let body: String
    let link: URL
    let author: String
    let score: Int
    let upvoted: Bool
    let bookmarked: Bool
    // A dozen other unmodified properties
    ...
    let commentCount: Int
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.title = try container.decode(String.self, forKey: .title)
        self.body = (try? container.decode(String.self, forKey: .body)) ?? ""
        self.link = try container.decode(URL.self, forKey: .link)
        self.author = try container.decode(String.self, forKey: .author)
        self.score = Int(try container.decode(String.self, forKey: .score)) ?? 0
        self.upvoted = try container.decode(Int.self, forKey: .upvoted) != 0
        self.bookmarked = (try? container.decode(Bool.self, forKey: .bookmarked)) ?? false
        // A dozen other unmodified properties
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        // self.foo = try container.decode(String.self, forKey: .foo)
        self.commentCount = try container.decode(Int.self, forKey: .commentCount)
    }
}
```

We didn't even need to adjust half of the properties we needed to decode, but we more than doubled the number of lines of this type by adding the initializer. There is also a lot of code duplication here: property names appear at least 3 times across the entire implementation, the types of properties are duplicated at least once because `Decoder` does not use the power of generics to supply the type parameters automatically, and `try container.decode` appears once fore every property in the model. On top of that, we have to explicitly unwrap the keyed container before we can do any real decoding.

We didn't need to rename any keys here, which is not an uncommon thing to do. If you need to rename or rearrange keys aside from the snake case conversion, you have to override `CodingKeys` too, even if it is only one key:

```swift
enum CodingKeys: String, CodingKey {
    case title = "name"
    case body, link, author, score, upvoted, bookmarked, commentCount
    // A dozen other keys
    case ...
}
```

I set out to make the "ideal" approach possible, and Jsum is what I came up with.

### Goals

- No unnecessary duplication of property names or types, ever
- Rarely need to opt out of automatic initialization
- Perform sane conversions automatically (i.e. string → number)
- A familiar API for customizing parts of decoding, like the date format
- Support decoding nearly any type, such as tuples or complex enums
- Must work seamlessly with classes and inheritance
- Minimize boilerplate above all else

## Usage

Let's continue with our example from above. Jsum is powerful enough to do everything for us without almost any intervention:

```swift
struct Post {
    let title: String
    let body: String
    let link: URL
    let author: String
    let score: Int
    let upvoted: Bool
    let bookmarked: Bool
    // A dozen other unmodified properties
    ...
    let commentCount: Int
}

let jsonObject = try JSONSerialization.jsonObject(
    with: "{ \"title\": … }".data(using: .utf8)!, options: []
)

let decoder = Jsum().keyDecoding(strategy: .convertFromSnakeCase)
let post: Post = try decoder.decode(from: jsonObject)
```

To summarize what exactly is going on here:

1. We did not explicitly conform to any protocols; decoding just works™
1. `body` is detected by Jsum as non-optional, so it is given a default value of `""` when it is not found or decoded as `null`
2. Assuming `URL` conforms to `JSONCodable`—the protocol provided by Jsum to customize decoding of your own types or other types—`link` will be decoded just like it would in Codable
3. `score` is automatically converted from a `String` to an `Int`
4. `upvoted` is automatically converted from an `Int` to a `Bool`
5. `bookmarked` is automatically coerced from `null` to `Bool`'s default value of `false`
6. We used `.convertFromSnakeCase` so `commentCount` was decoded from `"comment_count"`, but if we forgot, it would have been silently initialized with `0`

### Progressive disclosure

At this point you're probably thinking, "that's cool, but what if I want stricter type checking like Codable has?"

At a minimum, Jsum will always convert between strings/numbers/booleans automatically if the types do not match up. If you want `"score": "5"` to be a `String`, declare it as such. As for missing keys and `null`, you can opt into stricter checks like this:

```swift
// Throw when a key is missing and the property is non-optional
_ = Jsum().failOnMissingKeys()

// Throw when `null` is decoded and the property is non-optional
_ = Jsum().failOnNullNonOptionals()

// Throw for both of the above
_ = Jsum().failOnMissingKeys().failOnNullNonOptionals()
```

By default, both of these are turned off, so most properties will be given sensible default values if they cannot be decoded. This means that if you mistype a few keys, you usually won't find yourself spending ages debugging cryptic decoding errors before you can look at your decoded model.

I find that this allows me to iterate on features faster and more easily, and save the potential bugs for later. When you're trying to mock up a view, you don't necessarily want to have to deal with the types of problems I've outlined here right away; you might want to flatten those out later.

### Decode anything

One of my favorite things about Jsum is that it works on obscure types Codable won't handle, like tuples:

```swift
let person: (name: String, age: Int) = try Jsum.decode(
    from: ["name": "Bob", "age": 25]
)
```

It Just Works™ ^1

^1 *Decoding enums with raw values is pending unlocked existentials*

### Default values? Payload-restructuring? Value transformers?

It's all there. Check out `JSONCodable.swift` for more information.

Payload restructuring works just like Mantle's `JSONKeyPathsByPropertyKey`, except that you don't need to list out every key; only the ones you want to change. Just conform to `JSONCodable` and implement this property:

```
static var jsonKeyPathsByProperty: [String: String]
```

Value transformers work similarly; conform to `JSONCodable` and implement this property:

```
static var transformersByProperty: [String: AnyTransformer]
```

Unfortunately, neither of these APIs can use type-safe key paths because key paths do not expose any data to the programmer. Jsum cannot accept a key path and use it to look up the stringy-name of the property it refers to. If key paths ever provide a way to opt-into exposing the path information, I will update Jsum to make use of this.

### What about classes?

Jsum also works well with classes _and_ inheritance; something Codable makes difficult. I recommend having your classes conform to `Codable` to work around the `Class X has no initializers` error so you don't have to do something gross like `init() { fatalError() }`.

### Synthesizing entire types

If you look at `JSONCodable`, you'll see a static `synthesizesDefaultJSON` property. By default this property returns `false`. If you want entire objects of your model to be synthesized from nothing (useful during development when part of your model is incomplete) you can override this property to return `true` on any type, and if a non-optional property is missing from the payload or decoded as `null`, it will be constructed and synthesized from nothing. "JSON types" will be populated with sensible defaults (empty arrays, `0`/`false`/`""`) until somewhere a key path is reached where the type of the property a) doesn't implement `static var defaultJSON: JSON`, and b) doesn't override `synthesizesDefaultJSON` to return `true`

## Not production ready

Use this library at your own descretion. It is still in early active development. I am currently using it to build a Swift Forums client and adjusting the API and behaviors as I go for real world needs.
