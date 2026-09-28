--  A bounded layout tree: an arena of nodes linked by ids.
--
--  Design rules, all deliberate:
--    * No access types. Nodes live in a fixed array, links are ids.
--    * Append only. A node is inserted after its parent, so
--      Parent_Of (N) < N always holds. Any pass that visits nodes in
--      increasing id order visits parents before children; visiting
--      in decreasing order visits children before parents. The layout
--      algorithm relies on this instead of recursion.
--    * The Well_Formed predicate is the invariant every operation
--      preserves. It is what makes the geometry provable.

with Boxflex.Geometry; use Boxflex.Geometry;
with Boxflex.Style;    use Boxflex.Style;

package Boxflex.Tree with SPARK_Mode is

   type Node is record
      Style        : Flex_Style := Default_Style;
      Parent       : Node_Id    := No_Node;
      First_Child  : Node_Id    := No_Node;
      Last_Child   : Node_Id    := No_Node;
      Next_Sibling : Node_Id    := No_Node;
      Layout       : Rect       := Zero_Rect;
      --  Layout is the computed border box, in the coordinate space
      --  of the root. Written only by Boxflex.Layout.Compute.
   end record;

   type Node_Array is array (Valid_Node_Id) of Node;

   type Layout_Tree is record
      Count : Node_Id := No_Node;
      Nodes : Node_Array;
   end record;
   --  Nodes 1 .. Count are live. Count = 0 is the empty tree.

   ---------------------------------------------------------------------
   --  Queries
   ---------------------------------------------------------------------

   function Is_Valid (T : Layout_Tree; N : Node_Id) return Boolean is
     (N in 1 .. T.Count);

   function Is_Empty (T : Layout_Tree) return Boolean is (T.Count = 0);

   function Is_Full (T : Layout_Tree) return Boolean is
     (T.Count = Max_Nodes);

   function Well_Formed (T : Layout_Tree) return Boolean is
     (for all N in 1 .. T.Count =>
        T.Nodes (N).Parent < N
        and then T.Nodes (N).First_Child  <= T.Count
        and then T.Nodes (N).Last_Child   <= T.Count
        and then T.Nodes (N).Next_Sibling <= T.Count
        and then (T.Nodes (N).First_Child = No_Node
                  or else T.Nodes (N).First_Child > N)
        and then (T.Nodes (N).Next_Sibling = No_Node
                  or else T.Nodes (N).Next_Sibling > N)
        and then (T.Nodes (N).First_Child = No_Node)
                  = (T.Nodes (N).Last_Child = No_Node));
   --  The structural invariant:
   --    * every parent id is smaller than its child's id (so the
   --      root, if any, is node 1 and has Parent = No_Node),
   --    * every link points at a live node or at No_Node,
   --    * child and sibling links point forward (larger ids), so any
   --      walk along them terminates,
   --    * First_Child and Last_Child are both set or both unset.
   --  Not Ghost on purpose: tests call it, and with -gnata it is
   --  evaluated at runtime in every Pre/Post that names it.

   function Parent_Of (T : Layout_Tree; N : Node_Id) return Node_Id is
     (T.Nodes (N).Parent)
     with Pre => Is_Valid (T, N);

   function First_Child_Of (T : Layout_Tree; N : Node_Id) return Node_Id is
     (T.Nodes (N).First_Child)
     with Pre => Is_Valid (T, N);

   function Next_Sibling_Of (T : Layout_Tree; N : Node_Id) return Node_Id is
     (T.Nodes (N).Next_Sibling)
     with Pre => Is_Valid (T, N);

   function Style_Of (T : Layout_Tree; N : Node_Id) return Flex_Style is
     (T.Nodes (N).Style)
     with Pre => Is_Valid (T, N);

   function Layout_Of (T : Layout_Tree; N : Node_Id) return Rect is
     (T.Nodes (N).Layout)
     with Pre => Is_Valid (T, N);

   function Child_Count (T : Layout_Tree; N : Node_Id) return Natural
     with Pre => Is_Valid (T, N) and then Well_Formed (T);

   ---------------------------------------------------------------------
   --  Mutation
   ---------------------------------------------------------------------

   procedure Clear (T : in out Layout_Tree)
     with Post => Is_Empty (T) and then Well_Formed (T);

   procedure Insert
     (T      : in out Layout_Tree;
      Parent : Node_Id;
      Style  : Flex_Style;
      N      : out Node_Id)
     with
       Pre  => Well_Formed (T)
               and then not Is_Full (T)
               and then (Parent = No_Node or else Is_Valid (T, Parent))
               and then (Parent /= No_Node or else Is_Empty (T)),
       Post => Well_Formed (T)
               and then T.Count = T.Count'Old + 1
               and then N = T.Count
               and then Is_Valid (T, N)
               and then Parent_Of (T, N) = Parent
               and then Style_Of (T, N) = Style
               and then First_Child_Of (T, N) = No_Node
               and then Next_Sibling_Of (T, N) = No_Node;
   --  Appends a new node as the last child of Parent. Parent = No_Node
   --  creates the root, which is only allowed on an empty tree: a
   --  layout tree has exactly one root, node 1.

   procedure Set_Style
     (T : in out Layout_Tree; N : Node_Id; Style : Flex_Style)
     with
       Pre  => Well_Formed (T) and then Is_Valid (T, N),
       Post => Well_Formed (T)
               and then T.Count = T.Count'Old
               and then Style_Of (T, N) = Style;

   procedure Set_Layout
     (T : in out Layout_Tree; N : Node_Id; Layout : Rect)
     with
       Pre  => Well_Formed (T) and then Is_Valid (T, N),
       Post => Well_Formed (T)
               and then T.Count = T.Count'Old
               and then Layout_Of (T, N) = Layout;
   --  For Boxflex.Layout. Applications should not call this.

end Boxflex.Tree;
