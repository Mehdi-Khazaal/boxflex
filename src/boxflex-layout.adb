with Boxflex.Flex;

package body Boxflex.Layout with SPARK_Mode is

   use Boxflex.Flex;

   subtype Slot is Positive range 1 .. Max_Nodes;
   type Id_Array is array (Slot) of Node_Id;

   ---------------------------------------------------------------------
   --  Resolving style dimensions against the parent's content box
   ---------------------------------------------------------------------

   function Resolve
     (D : Dimension; Against : Length; Default : Length) return Length
   is
     (case D.Kind is
        when Fixed   => D.Value,
        when Percent => Length (D.Fraction * Against),
        when Auto | Content => Default);

   function Is_Definite (D : Dimension) return Boolean is
     (D.Kind in Fixed | Percent);

   ---------------------------------------------------------------------
   --  One child, as the engine sees it
   ---------------------------------------------------------------------

   function Make_Item
     (T       : Layout_Tree;
      N       : Node_Id;
      A       : Axis;
      Content : Size) return Item
     with Pre => Is_Valid (T, N);

   function Make_Item
     (T       : Layout_Tree;
      N       : Node_Id;
      A       : Axis;
      Content : Size) return Item
   is
      S : constant Flex_Style := Style_Of (T, N);

      Main_Avail  : constant Length := Main_Extent (Content, A);
      Cross_Avail : constant Length := Cross_Extent (Content, A);

      Main_Dim  : constant Dimension := (if A = Horizontal then S.Width  else S.Height);
      Cross_Dim : constant Dimension := (if A = Horizontal then S.Height else S.Width);
      Min_Main  : constant Dimension := (if A = Horizontal then S.Min_Width  else S.Min_Height);
      Max_Main  : constant Dimension := (if A = Horizontal then S.Max_Width  else S.Max_Height);
      Min_Cross : constant Dimension := (if A = Horizontal then S.Min_Height else S.Min_Width);
      Max_Cross : constant Dimension := (if A = Horizontal then S.Max_Height else S.Max_Width);

      Measured : constant Size := Measure (T, N, Content);

      I : Item;
   begin
      I.Grow   := S.Grow;
      I.Shrink := S.Shrink;
      I.Self   := S.Self;

      --  flex-basis: its own value, else the main-axis size, else content.
      if Is_Definite (S.Basis) then
         I.Basis := Resolve (S.Basis, Main_Avail, 0.0);
         I.Basis_Definite := True;
      elsif S.Basis.Kind = Auto and then Is_Definite (Main_Dim) then
         I.Basis := Resolve (Main_Dim, Main_Avail, 0.0);
         I.Basis_Definite := True;
      else
         I.Basis := 0.0;
         I.Basis_Definite := False;
      end if;

      I.Content_Main := Main_Extent (Measured, A);

      if Is_Definite (Cross_Dim) then
         I.Content_Cross  := Resolve (Cross_Dim, Cross_Avail, 0.0);
         I.Cross_Definite := True;
      else
         I.Content_Cross  := Cross_Extent (Measured, A);
         I.Cross_Definite := False;
      end if;

      I.Min_Main  := Resolve (Min_Main,  Main_Avail,  0.0);
      I.Max_Main  := Resolve (Max_Main,  Main_Avail,  Length'Last);
      I.Min_Cross := Resolve (Min_Cross, Cross_Avail, 0.0);
      I.Max_Cross := Resolve (Max_Cross, Cross_Avail, Length'Last);

      if A = Horizontal then
         I.Margin_Main_Start  := S.Margin.Left;
         I.Margin_Main_End    := S.Margin.Right;
         I.Margin_Cross_Start := S.Margin.Top;
         I.Margin_Cross_End   := S.Margin.Bottom;
      else
         I.Margin_Main_Start  := S.Margin.Top;
         I.Margin_Main_End    := S.Margin.Bottom;
         I.Margin_Cross_Start := S.Margin.Left;
         I.Margin_Cross_End   := S.Margin.Right;
      end if;

      return I;
   end Make_Item;

   -------------
   -- Compute --
   -------------

   procedure Compute
     (T         : in out Layout_Tree;
      Available : Size)
   is
      Ids   : Id_Array   := [others => No_Node];
      Items : Item_Array (Slot) := [others => <>];
   begin
      --  Start clean so every rect satisfies Placed from here on.
      for N in 1 .. T.Count loop
         pragma Loop_Invariant (Well_Formed (T));
         pragma Loop_Invariant (T.Count = T.Count'Loop_Entry);
         pragma Loop_Invariant
           (for all K in 1 .. T.Count =>
              Style_Of (T, K) = Style_Of (T'Loop_Entry, K));
         pragma Loop_Invariant
           (for all K in 1 .. N - 1 => Placed (Layout_Of (T, K)));
         Set_Layout (T, N, Zero_Rect);
      end loop;

      Set_Layout (T, 1, (Zero_Point, Available));

      --  Parents first (Well_Formed: Parent_Of (N) < N).
      for P in 1 .. T.Count loop
         pragma Loop_Invariant (Well_Formed (T));
         pragma Loop_Invariant (T.Count = T.Count'Loop_Entry);
         pragma Loop_Invariant
           (for all K in 1 .. T.Count =>
              Style_Of (T, K) = Style_Of (T'Loop_Entry, K));
         pragma Loop_Invariant (Layout_Of (T, 1) = (Zero_Point, Available));
         pragma Loop_Invariant
           (for all K in 1 .. T.Count => Placed (Layout_Of (T, K)));

         if First_Child_Of (T, P) /= No_Node then
            declare
               S   : constant Flex_Style := Style_Of (T, P);
               Box : constant Rect       := Layout_Of (T, P);
               A   : constant Axis :=
                 (if Is_Row (S) then Horizontal else Vertical);

               --  Content box: border box minus border and padding.
               --  Origin advances saturating; extent shrinks via Inset.
               Left : constant Length := S.Border.Left + S.Padding.Left;
               Top  : constant Length := S.Border.Top  + S.Padding.Top;
               Content : constant Rect :=
                 (Origin => (X => Advance (Box.Origin.X, Left),
                             Y => Advance (Box.Origin.Y, Top)),
                  Extent => Inset (Box,
                                   Left, Top,
                                   S.Border.Right  + S.Padding.Right,
                                   S.Border.Bottom + S.Padding.Bottom).Extent);

               C : constant Container :=
                 (Main      => Main_Extent (Content.Extent, A),
                  Cross     => Cross_Extent (Content.Extent, A),
                  Direction => S.Direction,
                  Wrap      => S.Wrap,
                  Justify   => S.Justify,
                  Align     => S.Align,
                  Lines     => S.Lines,
                  Main_Gap  => S.Gap,
                  Cross_Gap => S.Cross_Gap);

               Count : Natural := 0;
               Child : Node_Id := First_Child_Of (T, P);
            begin
               --  Gather the children, in order.
               while Child /= No_Node loop
                  pragma Loop_Variant (Increases => Child);
                  pragma Loop_Invariant (Is_Valid (T, Child));
                  pragma Loop_Invariant (Count < Natural (Child));
                  Count := Count + 1;
                  Ids (Count)   := Child;
                  Items (Count) := Make_Item (T, Child, A, Content.Extent);
                  Child := Next_Sibling_Of (T, Child);
               end loop;

               Resolve (C, Items (1 .. Count));

               --  Write back, mapping axes to X/Y.
               for K in 1 .. Count loop
                  pragma Loop_Invariant (Well_Formed (T));
                  pragma Loop_Invariant (T.Count = T.Count'Loop_Entry);
                  pragma Loop_Invariant
                    (for all J in 1 .. T.Count =>
                       Style_Of (T, J) = Style_Of (T'Loop_Entry, J));
                  pragma Loop_Invariant
                    (Layout_Of (T, 1) = (Zero_Point, Available));
                  pragma Loop_Invariant
                    (for all J in 1 .. T.Count => Placed (Layout_Of (T, J)));
                  declare
                     I : constant Item := Items (K);
                     R : Rect;
                  begin
                     if A = Horizontal then
                        R := Make
                          (X      => Place (Content.Origin.X, I.Pos_Main),
                           Y      => Place (Content.Origin.Y, I.Pos_Cross),
                           Width  => I.Main,
                           Height => I.Cross);
                     else
                        R := Make
                          (X      => Place (Content.Origin.X, I.Pos_Cross),
                           Y      => Place (Content.Origin.Y, I.Pos_Main),
                           Width  => I.Cross,
                           Height => I.Main);
                     end if;
                     Set_Layout (T, Ids (K), R);
                  end;
               end loop;
            end;
         end if;
      end loop;
   end Compute;

end Boxflex.Layout;
