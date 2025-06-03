{
  const o = {
    '1': true,
    '2': false,
  };
  o as {[number]: boolean}; // OK
  o as {[string]: boolean}; // OK
  o as {[symbol]: boolean}; // ERROR

  o as {[1 | 2]: boolean}; // OK
  o as {['1' | '2']: boolean}; // OK

  o as {[1 | 2 | 3]: boolean}; // OK
  o as {['1' | '2' | '3']: boolean}; // OK

  o as {[1]: boolean}; // ERROR
  o as {['1']: boolean}; // ERROR

  o as {'1': boolean, '2': boolean}; // OK
  o as {'1': true, [number]: false}; // OK
  o as {'1': true, [number]: true}; // ERROR

  '1' as $Keys<typeof o>; // OK
  o as {[$Keys<typeof o>]: boolean}; // OK
  '3' as $Keys<typeof o>; // ERROR
  const x: $Keys<typeof o> = 1; // ERROR

  Object.keys(o) as Array<number>; // ERROR
}

{
  const o = {
    '1': true,
    '2': false,
  };

  // Implicit instantiation
  {
    declare const f: <Key, Value>(o: {[Key]: Value}) => Key;
    const x = f(o);
    x as string; // OK
    x as number; // ERROR
  }
  // `number` upper bound
  {
    declare const f: <Key: number, Value>(o: {[Key]: Value}) => Key;
    const x = f(o); // ERROR
  }
  // Unrelated implicit instantiation
  {
    declare const f: <T>({[number]: boolean}, T) => T;
    const x = f(o, 's'); // OK
  }
  {
    declare const f: <T>({[number]: T}) => T;
    const x = f(o); // OK
  }
  // Conditional types
  {
    type GetKeys<T> = T extends {+[infer K]: mixed} ? K : empty;
    declare const x: GetKeys<{'1': boolean, '2': string}>;
    x as number; // ERROR
  }
}

{
  declare class MyMap<+K, +V> {
    static <K, V>({+[k: K]: V, ...}): MyMap<K, V>;
  }
  const map = MyMap({'1': true});
  map as MyMap<string, boolean>; // OK
}

{
  declare const o: {
    [number]: boolean,
    '1': 'one',
    '2': 'two',
  };

  o as {+[number]: boolean | string}; // OK
  o as {+[string]: string}; // ERROR

  o as {'1': 'one', '2': 'two', [number]: boolean}; // OK
  o as {'1': 'one', +[number]: boolean | 'two'}; // OK

  o as {'1': 'one', '2': 'two', '3': boolean, [number]: boolean}; // OK
}

// Negative numbers
{
  const o = {
    '-1': true,
    '-2': false,
  };
  o as {[number]: boolean}; // OK
  o as {[string]: boolean}; // OK
}

// Only int-like keys allowed
{
  const o = {
    '1.0234': true,
  };
  o as {[number]: boolean}; // ERROR
  o as {[string]: boolean}; // OK
}

// Larger than max safe int
{
  const o = {
    '9007199254740992': true,
  };
  o as {[number]: boolean}; // ERROR
  o as {[string]: boolean}; // OK
}

// Creation with computed prop
{
  const o = {
    [1]: true,
    [9007199254740991]: false,
  };
  o[1] as boolean; // OK
  o['1'] as boolean; // OK
  o[9007199254740991.0] as boolean; // OK
  o['9007199254740991'] as boolean; // OK
  o[1] as empty; // ERROR
  o['1'] as empty; // ERROR
}

{
  const E = Object.freeze({
    One: 1,
  });
  const o = {
    [E.One]: true,
  };
  o[1] as boolean; // OK
  o['1'] as boolean; // OK
  o[1] as empty; // ERROR
  o['1'] as empty; // ERROR
}

// Number literal shorthands
{
  const o = {
    [1E3]: true, // OK
    [0XA]: true, // OK
    [010]: true, // OK
  };
  // 1E3
  o[1000] as boolean; // OK
  o[1000] as empty; // ERROR
  // 0XA
  o[10] as boolean; // OK
  o[10] as empty; // ERROR
  // 010
  o[8] as boolean; // OK
  o[8] as empty; // ERROR
}

// Access of dicts
{
  declare const x: {[number]: boolean};
  x[1] as boolean; // OK
  x[1.1] as boolean; // OK
  x['1'] as boolean; // OK
  x['foo']; // ERROR
}

{
  declare const x: {[string]: boolean};
  x[1] as boolean; // OK - same as below
  x['1'] as boolean; // OK
}

// Invalid access
{
  const x = {};
  x[1.1]; // ERROR
  x[9007199254740992]; // ERROR
}

// Invalid creation
{
  const x = {
    [1.1]: true, // ERROR
    [9007199254740992]: false, // ERROR
    [-9007199254740992]: false, // ERROR
  };
  const y = {
    1.1: true, // ERROR
    9007199254740992: false, // ERROR
  };
}

// Direct creation
{
  const o = {
    1: true,
    9007199254740991: false,
  };
  o[1] as boolean; // OK
  o[9007199254740991] as boolean; // OK
  o[1] as empty; // ERROR
  o[9007199254740991] as empty; // ERROR
}
