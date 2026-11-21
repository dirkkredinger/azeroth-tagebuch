//! Liest das Lua-Format, das WoW für SavedVariables schreibt (Zuweisungen mit Tabellen).

use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq)]
pub enum Lua {
    Str(String),
    Num(f64),
    Bool(bool),
    Table(Table),
    Nil,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Table {
    /// Einträge ohne Schlüssel (Array-Teil)
    pub array: Vec<Lua>,
    /// Einträge mit Schlüssel; Zahlenschlüssel als Text ("1", "2", …)
    pub dict: HashMap<String, Lua>,
}

impl Table {
    /// Alle Array-Einträge in Reihenfolge, auch wenn sie als `[1] = …` geschrieben wurden.
    pub fn items(&self) -> Vec<&Lua> {
        let mut numeric: Vec<(i64, &Lua)> = self
            .dict
            .iter()
            .filter_map(|(k, v)| k.parse::<i64>().ok().map(|n| (n, v)))
            .collect();
        numeric.sort_by_key(|(n, _)| *n);
        self.array.iter().chain(numeric.into_iter().map(|(_, v)| v)).collect()
    }
}

impl Lua {
    pub fn get(&self, key: &str) -> Option<&Lua> {
        match self {
            Lua::Table(t) => t.dict.get(key),
            _ => None,
        }
    }
    pub fn table(&self) -> Option<&Table> {
        match self {
            Lua::Table(t) => Some(t),
            _ => None,
        }
    }
    pub fn str(&self) -> Option<String> {
        match self {
            Lua::Str(s) => Some(s.clone()),
            Lua::Num(n) => Some(if n.fract() == 0.0 { format!("{}", *n as i64) } else { n.to_string() }),
            Lua::Bool(b) => Some(b.to_string()),
            _ => None,
        }
    }
    pub fn num(&self) -> Option<f64> {
        match self {
            Lua::Num(n) => Some(*n),
            Lua::Str(s) => s.parse().ok(),
            _ => None,
        }
    }
    pub fn int(&self) -> Option<i64> {
        self.num().filter(|n| n.is_finite()).map(|n| n.round() as i64)
    }
    pub fn bool(&self) -> Option<bool> {
        match self {
            Lua::Bool(b) => Some(*b),
            _ => None,
        }
    }
}

/// Kurzform: Feld einer Tabelle als Text/Zahl
pub fn s(v: &Lua, k: &str) -> Option<String> { v.get(k).and_then(Lua::str) }
pub fn i(v: &Lua, k: &str) -> Option<i64> { v.get(k).and_then(Lua::int) }
pub fn f(v: &Lua, k: &str) -> Option<f64> { v.get(k).and_then(Lua::num) }

#[derive(Debug)]
pub struct ParseError {
    pub message: String,
    pub offset: usize,
}

impl std::fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Lesefehler bei Byte {}: {}", self.offset, self.message)
    }
}
impl std::error::Error for ParseError {}

/// Liest alle Zuweisungen `Name = Wert` einer SavedVariables-Datei.
pub fn parse_assignments(data: &[u8]) -> Result<HashMap<String, Lua>, ParseError> {
    let mut p = Parser { b: data, i: 0 };
    // UTF-8-BOM überspringen
    if p.b.starts_with(&[0xEF, 0xBB, 0xBF]) {
        p.i = 3;
    }
    let mut out = HashMap::new();
    loop {
        p.skip();
        if p.i >= p.b.len() {
            break;
        }
        let name = p.identifier()?;
        p.skip();
        p.expect(b'=')?;
        let v = p.value()?;
        out.insert(name, v);
    }
    Ok(out)
}

struct Parser<'a> {
    b: &'a [u8],
    i: usize,
}

impl<'a> Parser<'a> {
    fn err<T>(&self, msg: &str) -> Result<T, ParseError> {
        Err(ParseError { message: msg.to_string(), offset: self.i })
    }

    fn peek(&self) -> Option<u8> { self.b.get(self.i).copied() }

    fn skip(&mut self) {
        while let Some(c) = self.peek() {
            if c.is_ascii_whitespace() || c == b';' {
                self.i += 1;
            } else if c == b'-' && self.b.get(self.i + 1) == Some(&b'-') {
                // Kommentar bis Zeilenende (WoW schreibt nur Zeilenkommentare wie "-- [1]")
                while let Some(c) = self.peek() {
                    if c == b'\n' { break; }
                    self.i += 1;
                }
            } else {
                break;
            }
        }
    }

    fn expect(&mut self, c: u8) -> Result<(), ParseError> {
        self.skip();
        if self.peek() == Some(c) {
            self.i += 1;
            Ok(())
        } else {
            self.err(&format!("'{}' erwartet", c as char))
        }
    }

    fn identifier(&mut self) -> Result<String, ParseError> {
        let start = self.i;
        while let Some(c) = self.peek() {
            if c.is_ascii_alphanumeric() || c == b'_' { self.i += 1; } else { break; }
        }
        if start == self.i {
            return self.err("Name erwartet");
        }
        Ok(String::from_utf8_lossy(&self.b[start..self.i]).into_owned())
    }

    fn value(&mut self) -> Result<Lua, ParseError> {
        self.skip();
        match self.peek() {
            Some(b'{') => Ok(Lua::Table(self.table()?)),
            Some(b'"') | Some(b'\'') => Ok(Lua::Str(self.string()?)),
            Some(c) if c == b'-' || c == b'.' || c.is_ascii_digit() => Ok(Lua::Num(self.number()?)),
            Some(_) => {
                let word = self.identifier()?;
                match word.as_str() {
                    "true" => Ok(Lua::Bool(true)),
                    "false" => Ok(Lua::Bool(false)),
                    "nil" => Ok(Lua::Nil),
                    "inf" => Ok(Lua::Num(f64::INFINITY)),
                    "nan" => Ok(Lua::Num(f64::NAN)),
                    _ => self.err(&format!("unbekannter Wert {word}")),
                }
            }
            None => self.err("Wert erwartet"),
        }
    }

    fn number(&mut self) -> Result<f64, ParseError> {
        let start = self.i;
        if self.peek() == Some(b'-') { self.i += 1; }
        // Hexadezimal
        if self.peek() == Some(b'0') && matches!(self.b.get(self.i + 1), Some(b'x') | Some(b'X')) {
            self.i += 2;
            let hs = self.i;
            while let Some(c) = self.peek() { if c.is_ascii_hexdigit() { self.i += 1; } else { break; } }
            let v = i64::from_str_radix(std::str::from_utf8(&self.b[hs..self.i]).unwrap_or("0"), 16).unwrap_or(0) as f64;
            return Ok(if self.b[start] == b'-' { -v } else { v });
        }
        while let Some(c) = self.peek() {
            if c.is_ascii_digit() || matches!(c, b'.' | b'e' | b'E' | b'+' | b'-') { self.i += 1; } else { break; }
        }
        let text = std::str::from_utf8(&self.b[start..self.i]).unwrap_or("");
        match text {
            "-inf" => Ok(f64::NEG_INFINITY),
            _ => text.parse().or_else(|_| self.err("Zahl erwartet")),
        }
    }

    fn string(&mut self) -> Result<String, ParseError> {
        let quote = self.b[self.i];
        self.i += 1;
        let mut out: Vec<u8> = Vec::new();
        loop {
            let Some(c) = self.peek() else { return self.err("Text nicht abgeschlossen") };
            self.i += 1;
            if c == quote { break; }
            if c != b'\\' { out.push(c); continue; }
            let Some(e) = self.peek() else { return self.err("Escape am Ende") };
            self.i += 1;
            match e {
                b'n' => out.push(b'\n'),
                b't' => out.push(b'\t'),
                b'r' => out.push(b'\r'),
                b'a' => out.push(7),
                b'b' => out.push(8),
                b'f' => out.push(12),
                b'v' => out.push(11),
                b'\n' => out.push(b'\n'),
                b'0'..=b'9' => {
                    let mut v: u32 = (e - b'0') as u32;
                    for _ in 0..2 {
                        match self.peek() {
                            Some(d) if d.is_ascii_digit() => { v = v * 10 + (d - b'0') as u32; self.i += 1; }
                            _ => break,
                        }
                    }
                    out.push((v & 0xFF) as u8);
                }
                other => out.push(other),
            }
        }
        Ok(String::from_utf8_lossy(&out).into_owned())
    }

    fn table(&mut self) -> Result<Table, ParseError> {
        self.expect(b'{')?;
        let mut t = Table::default();
        loop {
            self.skip();
            match self.peek() {
                Some(b'}') => { self.i += 1; break; }
                Some(b'[') => {
                    self.i += 1;
                    let key = self.value()?;
                    self.expect(b']')?;
                    self.expect(b'=')?;
                    let v = self.value()?;
                    let k = key.str().unwrap_or_default();
                    t.dict.insert(k, v);
                }
                Some(c) if c.is_ascii_alphabetic() || c == b'_' => {
                    // name = wert  oder  ein Wort als Wert (true/false/nil)
                    let save = self.i;
                    let name = self.identifier()?;
                    self.skip();
                    if self.peek() == Some(b'=') {
                        self.i += 1;
                        let v = self.value()?;
                        t.dict.insert(name, v);
                    } else {
                        self.i = save;
                        let v = self.value()?;
                        t.array.push(v);
                    }
                }
                Some(_) => {
                    let v = self.value()?;
                    t.array.push(v);
                }
                None => return self.err("Tabelle nicht abgeschlossen"),
            }
            self.skip();
            if self.peek() == Some(b',') { self.i += 1; }
        }
        Ok(t)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn liest_tabellen() {
        let src = br#"
X = {
  ["a"] = 1, -- Kommentar
  [2] = "zwei\"\n",
  { ["t"] = 5 }, -- [1]
  b = true,
  neg = -1.5e2,
}
"#;
        let v = parse_assignments(src).unwrap();
        let x = &v["X"];
        assert_eq!(i(x, "a"), Some(1));
        assert_eq!(s(x, "2").as_deref(), Some("zwei\"\n"));
        assert_eq!(x.get("b").and_then(Lua::bool), Some(true));
        assert_eq!(f(x, "neg"), Some(-150.0));
        assert_eq!(x.table().unwrap().items().len(), 2);
    }
}
