package body Boxflex.Tree with SPARK_Mode is

   -----------------
   -- Child_Count --
   -----------------

   function Child_Count (T : Layout_Tree; N : Node_Id) return Natural is
      C     : Node_Id := T.Nodes (N).First_Child;
      Count : Natural := 0;
   begin
      while C /= No_Node loop
         --  Sibling ids strictly increase (Well_Formed), so the walk
         --  terminates and Count is bounded by the current id.
         pragma Loop_Variant (Increases => C);
         pragma Loop_Invariant (Is_Valid (T, C));
         pragma Loop_Invariant (Count < Natural (C));
         Count := Count + 1;
         C := T.Nodes (C).Next_Sibling;
      end loop;
      return Count;
   end Child_Count;

   -----------
   -- Clear --
   -----------

   procedure Clear (T : in out Layout_Tree) is
   begin
      T.Count := No_Node;
   end Clear;

   ------------
   -- Insert --
   ------------

   procedure Insert
     (T      : in out Layout_Tree;
      Parent : Node_Id;
      Style  : Flex_Style;
      N      : out Node_Id)
   is
   begin
      T.Count := T.Count + 1;
      N := T.Count;

      T.Nodes (N) :=
        (Style        => Style,
         Parent       => Parent,
         First_Child  => No_Node,
         Last_Child   => No_Node,
         Next_Sibling => No_Node,
         Layout       => Zero_Rect);

      if Parent /= No_Node then
         if T.Nodes (Parent).First_Child = No_Node then
            T.Nodes (Parent).First_Child := N;
         else
            T.Nodes (T.Nodes (Parent).Last_Child).Next_Sibling := N;
         end if;
         T.Nodes (Parent).Last_Child := N;
      end if;
   end Insert;

   ---------------
   -- Set_Style --
   ---------------

   procedure Set_Style
     (T : in out Layout_Tree; N : Node_Id; Style : Flex_Style) is
   begin
      T.Nodes (N).Style := Style;
   end Set_Style;

   ----------------
   -- Set_Layout --
   ----------------

   procedure Set_Layout
     (T : in out Layout_Tree; N : Node_Id; Layout : Rect) is
   begin
      T.Nodes (N).Layout := Layout;
   end Set_Layout;

end Boxflex.Tree;
