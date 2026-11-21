# Python-Nachbau der Swift-Parserlogik (gleiche Verzweigungen) zum Prüfen der Beispieldaten
import sys
def parse(b):
    i=0; n=len(b)
    def skip():
        nonlocal i
        while i<n:
            c=b[i]
            if c in (32,9,10,13): i+=1; continue
            if c==45 and i+1<n and b[i+1]==45:
                i+=2
                if i+1<n and b[i]==91 and b[i+1]==91:
                    i+=2
                    while i+1<n and not(b[i]==93 and b[i+1]==93): i+=1
                    i=min(i+2,n)
                else:
                    while i<n and b[i]!=10: i+=1
                continue
            break
    ids=lambda c:(65<=c<=90) or (97<=c<=122) or c==95
    idc=lambda c: ids(c) or 48<=c<=57
    def ident():
        nonlocal i
        assert i<n and ids(b[i]), ("ident",i); s=i
        while i<n and idc(b[i]): i+=1
        return b[s:i].decode()
    def expect(c):
        nonlocal i
        skip(); assert i<n and b[i]==c,(chr(c),i); i+=1
    def number():
        nonlocal i
        s=i
        if b[i]==45: i+=1
        while i<n:
            c=b[i]
            if 48<=c<=57 or c in (101,69,46) or (c in(45,43) and i>s and b[i-1] in(101,69)): i+=1
            else: break
        return float(b[s:i])
    def string():
        nonlocal i
        q=b[i]; i+=1; out=bytearray()
        while i<n:
            c=b[i]
            if c==q: i+=1; return out.decode()
            if c==92:
                i+=1; e=b[i]
                if e==110: out.append(10); i+=1
                elif e==116: out.append(9); i+=1
                elif 48<=e<=57:
                    v=0;k=0
                    while k<3 and i<n and 48<=b[i]<=57: v=v*10+b[i]-48; i+=1; k+=1
                    out.append(v&255)
                else: out.append(e); i+=1
                continue
            out.append(c); i+=1
        raise Exception("unterminated")
    def value():
        nonlocal i
        skip(); c=b[i]
        if c==123: return table()
        if c in (34,39): return string()
        if c in (45,46) or 48<=c<=57: return number()
        w=ident(); return {"true":True,"false":False,"nil":None}[w]
    def key(v):
        if isinstance(v,float): return str(int(v)) if v==int(v) else str(v)
        return v
    def table():
        nonlocal i
        i+=1; arr=[]; d={}
        while True:
            skip()
            if b[i]==125: i+=1; return (arr,d)
            if b[i]==91:
                i+=1; k=value(); expect(93); expect(61); d[key(k)]=value()
            elif ids(b[i]):
                save=i; w=ident(); skip()
                if b[i]==61 and b[i+1]!=61: i+=1; d[w]=value()
                else: i=save; arr.append(value())
            else: arr.append(value())
            skip()
            if i<n and b[i] in (44,59): i+=1
    res={}
    skip()
    while i<n:
        name=ident(); expect(61); res[name]=value(); skip()
    return res
r=parse(open(sys.argv[1],'rb').read())
arr,d=r["AzerothTagebuchDB"]
chars=d["chars"][1]
for k,(a,cd) in chars.items():
    evs=cd["events"][0]
    kinds={}
    for e in evs:
        t=e[1]["e"]; kinds[t]=kinds.get(t,0)+1
    print(k, cd["level"], len(evs), kinds)
print("maps", {k:v[1]["n"] for k,v in d["maps"][1].items()})
