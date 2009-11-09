{-# LANGUAGE BangPatterns #-}
module Graphics.Vty.DisplayAttributes
    where

import Graphics.Vty.Attributes

import Data.Bits ( (.&.) )
import Data.Monoid ( Monoid(..), mconcat )

-- | Given the previously applied display attributes as a FixedAttr and the current display
-- attributes as an Attr produces a FixedAttr that represents the current display attributes. This
-- is done by using the previously applied display attributes to remove the "KeepCurrent"
-- abstraction.
fix_display_attr :: FixedAttr -> Attr -> FixedAttr
fix_display_attr fattr attr 
    = FixedAttr ( fix_style (fixed_style fattr) (attr_style attr) )
                ( fix_color (fixed_fore_color fattr) (attr_fore_color attr) )
                ( fix_color (fixed_back_color fattr) (attr_back_color attr) )
    where
        fix_style _s Default = default_style_mask
        fix_style s KeepCurrent = s
        fix_style _s (SetTo new_style) = new_style
        fix_color _c Default = Nothing
        fix_color c KeepCurrent = c
        fix_color _c (SetTo c) = Just c

data DisplayAttrDiff = DisplayAttrDiff
    { style_diffs :: [ StyleStateChange ]
    , fore_color_diff :: DisplayColorDiff
    , back_color_diff :: DisplayColorDiff
    }

instance Monoid DisplayAttrDiff where
    mempty = DisplayAttrDiff [] NoColorChange NoColorChange
    mappend d_0 d_1 = 
        let ds = simplify_style_diffs ( style_diffs d_0 ) ( style_diffs d_1 )
            fcd = simplify_color_diffs ( fore_color_diff d_0 ) ( fore_color_diff d_1 )
            bcd = simplify_color_diffs ( back_color_diff d_0 ) ( back_color_diff d_1 )
        in DisplayAttrDiff ds fcd bcd

simplify_style_diffs :: [ StyleStateChange ] -> [ StyleStateChange ] -> [ StyleStateChange ]
simplify_style_diffs cs_0 cs_1 = cs_0 `mappend` cs_1

simplify_color_diffs _cd             ColorToDefault  = ColorToDefault
simplify_color_diffs cd              NoColorChange   = cd
simplify_color_diffs _cd             ( SetColor !c ) = SetColor c

data DisplayColorDiff 
    = ColorToDefault
    | NoColorChange
    | SetColor !Color
    deriving Eq

data StyleStateChange 
    = ApplyStandout
    | RemoveStandout
    | ApplyUnderline
    | RemoveUnderline
    | ApplyReverseVideo
    | RemoveReverseVideo
    | ApplyBlink
    | RemoveBlink
    | ApplyDim
    | RemoveDim
    | ApplyBold
    | RemoveBold

display_attr_diffs :: FixedAttr -> FixedAttr -> DisplayAttrDiff
display_attr_diffs attr attr' = DisplayAttrDiff
    { style_diffs = diff_styles ( fixed_style attr ) ( fixed_style attr' )
    , fore_color_diff = diff_color ( fixed_fore_color attr ) ( fixed_fore_color attr' )
    , back_color_diff = diff_color ( fixed_back_color attr ) ( fixed_back_color attr' )
    }

diff_color :: Maybe Color -> Maybe Color -> DisplayColorDiff
diff_color Nothing  (Just c') = SetColor c'
diff_color (Just c) (Just c') 
    | c == c'   = NoColorChange
    | otherwise = SetColor c'
diff_color Nothing  Nothing = NoColorChange
diff_color (Just _) Nothing = ColorToDefault

diff_styles :: Style -> Style -> [StyleStateChange]
diff_styles prev cur 
    = mconcat 
    [ style_diff standout ApplyStandout RemoveStandout
    , style_diff underline ApplyUnderline RemoveUnderline
    , style_diff reverse_video ApplyReverseVideo RemoveReverseVideo
    , style_diff blink ApplyBlink RemoveBlink
    , style_diff dim ApplyDim RemoveDim
    , style_diff bold ApplyBold RemoveBold
    ]
    where 
        style_diff s sm rm 
            = case ( 0 == prev .&. s, 0 == cur .&. s ) of
                -- not set in either
                ( True, True ) -> []
                -- set in both
                ( False, False ) -> []
                -- now set
                ( True, False) -> [ sm ]
                -- now unset
                ( False, True) -> [ rm ]

