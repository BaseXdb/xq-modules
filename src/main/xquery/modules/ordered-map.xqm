xquery version "3.0";

(:~
 : Abstract interface for an ordered map.
 :
 : @author Leo Woerteler &lt;leo@woerteler.de&gt;
 : @version 0.1
 : @license BSD 2-Clause License
 :)
module namespace ordered-map = 'http://www.woerteler.de/xquery/modules/ordered-map';

(:~ Pairs for grouping root and less-than predicate together. :)
import module namespace pair = 'http://www.woerteler.de/xquery/modules/pair' at 'pair.xqm';

(:~
 : The exchangeable implementation of the map.
 : Each implementation has to provide the following methods:
 : <ul>
 :   <li><code>empty() as item()*</code> returns the empty map</li>
 :   <li><code>lookup($lt, $root, $key, $found, $notFound) as item()*</code>
 :         searches for the given key and calls <code>$found($val)</code>
 :         if the map contains the entry <code>($key, $val)</code>
 :         and <code>$notFound()</code> otherwise</li>
 :   <li><code>insert($lt, $root, $key, $val) as item()*</code>
 :         inserts the entry <code>($key, $val)</code> into <code>$root</code>
 :         and returns the resulting map</li>
 :   <li><code>delete($lt, $root, $key) as item()*</code>
 :         deletes the entry with key <code>$key</code> from <code>$root</code>
 :         and returns the resulting map</li>
 :   <li><code>check($lt, $root, $min, $max, $msg) as item()*</code></li>
 :   <li><code>fold($node, $acc, $f) as item()*</code></li>
 :   <li><code>to-xml($root) as element()</code></li>
 : </ul>
 :)
import module namespace impl = 'http://www.woerteler.de/xquery/modules/ordered-map/avltree'
  at 'ordered_map/avltree.xqm';

(:~
 : Creates a new map with the given less-than predicate.
 : @param $lt less-than predicate
 : @return the empty map
 :)
declare %public function ordered-map:new(
  $lt as function(item()*, item()*) as xs:boolean
) as function(*) {
  pair:new($lt, impl:empty())
};

(:~
 : Looks up the given key in the given map and calls the corresponding callback.
 : @param $m the map to search in
 : @param $k key to look up
 : @param $found callback for when the key was found
 : @param $notFound callback for when the key was not found
 : @return result from the callback
 :)
declare %public function ordered-map:lookup(
  $m as function(*),
  $k as item()*,
  $found as function(item()*) as item()*,
  $notFound as function() as item()*
) as item()* {
  pair:deconstruct(
    $m,
    function($lt, $root) {
      impl:lookup($lt, $root, $k, $found, $notFound)
    }
  )
};

(:~
 : Checks if the given map contains an entry with the given key.
 :
 : @param $m map to look in
 : @param $k key to look for
 : @return <code>true()</code> if the key is in the map, <code>false()</code> otherwise
 :)
declare %public function ordered-map:contains(
  $m as function(*),
  $k as item()*
) as xs:boolean {
  ordered-map:lookup(
    $m,
    $k,
    function($_) { true()  },
    function()   { false() }
  )
};

(:~
 : Gets the value bound to the given key in the given map.
 :
 : @param $m the map
 : @param $k key to look up
 : @return the bound value if the key exists in the map, <code>()</code> otherwise
 :)
declare %public function ordered-map:get(
  $m as function(*),
  $k as item()*
) as item()* {
  ordered-map:lookup(
    $m,
    $k,
    function($v) { $v },
    function() { () }
  )
};

(:~
 : Determines the number of entries in the given map.
 : @param $m map to determine the number of entries of
 : @return number of entries
 :)
declare %public function ordered-map:size(
  $m as function(*)
) as xs:integer {
  impl:fold(
    pair:second($m),
    0,
    function($size, $k, $v) { $size + 1 }
  )
};

(:~
 : Inserts the given key and value into the given map and returns the new map.
 : @param $m map to insert into
 : @param $k key to insert
 : @param $v value to insert
 : @return the new map
 :)
declare %public function ordered-map:insert(
  $m as function(*),
  $k as item()*,
  $v as item()*
) as item()* {
  pair:deconstruct(
    $m,
    function($lt, $root) {
      pair:new($lt, impl:insert($lt, $root, $k, $v))
    }
  )
};

(:~
 : Deletes the given key from the map if it exists.
 : @param $m map to delete from
 : @param $k key to delete
 : @return map that does not contain the deleted key
 :)
declare %public function ordered-map:delete(
  $m as function(*),
  $k as item()*
) as function(*) {
  pair:deconstruct(
    $m,
    function($lt, $root) {
      pair:new($lt, impl:delete($lt, $root, $k))
    }
  )
};

(:~
 : Checks the structural consistency of the given map.
 : @param $m the map to check
 : @param $minExcl a key that is smaller than all keys in the map
 : @param $maxExcl a key that is greater than all keys in the map
 : @param message to display when the check fails
 : @return the map
 :)
declare %public function ordered-map:check(
  $m as function(*),
  $min as item()*,
  $max as item()*,
  $msg as xs:string
) as function(*) {
  pair:deconstruct(
    $m,
    function($lt, $root) {
      (impl:check($lt, $root, $min, $max, $msg), $m)[last()]
    }
  )
};

(:~
 : Returns an XML document showing the inner structure of the given map.
 : @param $m the map
 : @return structure of <code>$m</code> as XML document
 :)
declare %public function ordered-map:to-xml(
  $m as function(*)
) as document-node() {
  document{
    impl:to-xml(pair:second($m))
  }
};

(:~
 : Combines all entries in the given map in ascending order using
 : the user-supplied function <code>$f</code>.
 : For a map <code>$m</code> containing the entries
 : <code>{($k1, $v1), ($k2, $v2), ($k3, $v3)}</code>
 : with <code>$k1 &lt; $k2 &lt; $k3</code>, the call <code>fold($m, $z, $f)</code>
 : would return <code>$f($f($f($z, $k1, $v1), $k2, $v2), $k3, $v3)</code>.
 :
 : @param $m the map to fold
 : @param $z starting value
 : @param $f combining function
 : @return the folded value
 :)
declare %public function ordered-map:fold(
  $m as function(*),
  $z as item()*,
  $f as function(item()*, item()*, item()*) as item()*
) as item()* {
  impl:fold(pair:second($m), $z, $f)
};

(:~
 : Calls the given function for every entry in the map and concatenates the result sequences.
 : @param $m the map to iterate over
 : @param $f binary function taking the key and value of the entry
 : @return concatenated results of the calls to <code>$f</code>
 :)
declare %public function ordered-map:for-each-entry(
  $m as function(*),
  $f as function(item()*, item()*) as item()*
) as item()* {
  ordered-map:fold(
    $m,
    (),
    function($seq, $k, $v) { $seq, $f($k, $v) }
  )
};
