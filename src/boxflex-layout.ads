--  The tree walk: drives Boxflex.Flex over a Boxflex.Tree.
--
--  This is one client of the engine, the one used on bare metal where
--  there is no toolkit. Desktop toolkits (adi2) keep their own tree and
--  call Boxflex.Flex.Resolve directly; see adapters/.
--
--  Content measurement is the only thing a tree walk needs from the
--  outside: how big does a leaf want to be? That is the generic formal.
--  A text engine, a sprite atlas, or nothing at all (Boxflex.Layout_Plain)
--  can answer it.
--
--  Compute is already the real walk. It does what a walk does: resets
--  every rect, gives the root the available size, then for every
--  container in id order (parents first, see Well_Formed) gathers its
--  children into a Flex.Item_Array, calls Resolve, and writes each
--  child's border box back in root coordinates. What it leaves to the
--  team, besides Resolve itself:
--    * a bottom-up pass so a container's own content size comes from
--      its children (today Auto-sized containers get Content = 0),
--    * percentages against the parent's content box,
--    * Row_Reverse / Column_Reverse, which flip the main axis origin.

with Boxflex.Geometry; use Boxflex.Geometry;
with Boxflex.Style;    use Boxflex.Style;
with Boxflex.Tree;     use Boxflex.Tree;

generic
   with function Measure
     (T : Layout_Tree; N : Node_Id; Available : Size) return Size;
   --  The content size of node N (a leaf, or a container whose
   --  children are not yet laid out) given the space on offer. Only
   --  consulted when the style leaves the size Auto.
package Boxflex.Layout with SPARK_Mode is

   procedure Compute
     (T         : in out Layout_Tree;
      Available : Size)
     with
       Pre  => Well_Formed (T) and then not Is_Empty (T),
       Post => Well_Formed (T)
               and then T.Count = T.Count'Old
               and then (for all N in 1 .. T.Count =>
                           Style_Of (T, N) = Style_Of (T'Old, N))
               and then Layout_Of (T, 1) = (Zero_Point, Available)
               and then (for all N in 1 .. T.Count =>
                           Edges_In_Range (Layout_Of (T, N)));
   --  Lays out the whole tree inside Available. Node 1 (the root) gets
   --  the origin and the full available size. Structure and styles are
   --  untouched; only Layout fields change. Every resulting rect has
   --  computable far edges.

end Boxflex.Layout;
