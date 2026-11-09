#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKAttrIdentifiers.m
//  Lookin
//
//  Created by Li Kai on 2019/9/18.
//  https://lookin.work
//



#import "SPLKAttrIdentifiers.h"

// value 不能重复（AppDelegate 里的 runTests 有相关 test）
// 如果要去掉某一项可以考虑注释掉而非直接删除，以防止新项和旧项的 value 相同而引发 preference 错乱（这些 value 会被存储到 userDefaults 里）

#pragma mark - Group

SPLKAttrGroupIdentifier const SPLKAttrGroup_None = @"n";
SPLKAttrGroupIdentifier const SPLKAttrGroup_Class = @"c";
SPLKAttrGroupIdentifier const SPLKAttrGroup_Relation = @"r";
SPLKAttrGroupIdentifier const SPLKAttrGroup_Layout = @"l";
SPLKAttrGroupIdentifier const SPLKAttrGroup_AutoLayout = @"a";
SPLKAttrGroupIdentifier const SPLKAttrGroup_ViewLayer = @"vl";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UIImageView = @"i";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UILabel = @"la";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UIControl = @"co";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UIButton = @"b";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UIScrollView = @"s";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UITableView = @"ta";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UITextView = @"te";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UITextField = @"tf";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UIVisualEffectView = @"ve";
SPLKAttrGroupIdentifier const SPLKAttrGroup_UIStackView = @"UIStackView";

SPLKAttrGroupIdentifier const SPLKAttrGroup_UserCustom = @"guc"; // user custom

#pragma mark - Section

SPLKAttrSectionIdentifier const SPLKAttrSec_None = @"n";

SPLKAttrSectionIdentifier const SPLKAttrSec_UserCustom = @"sec_ctm";

SPLKAttrSectionIdentifier const SPLKAttrSec_Class_Class = @"cl_c";

SPLKAttrSectionIdentifier const SPLKAttrSec_Relation_Relation = @"r_r";

SPLKAttrSectionIdentifier const SPLKAttrSec_Layout_Frame = @"l_f";
SPLKAttrSectionIdentifier const SPLKAttrSec_Layout_Bounds = @"l_b";
SPLKAttrSectionIdentifier const SPLKAttrSec_Layout_SafeArea = @"l_s";
SPLKAttrSectionIdentifier const SPLKAttrSec_Layout_Position = @"l_p";
SPLKAttrSectionIdentifier const SPLKAttrSec_Layout_AnchorPoint = @"l_a";

SPLKAttrSectionIdentifier const SPLKAttrSec_AutoLayout_Hugging = @"a_h";
SPLKAttrSectionIdentifier const SPLKAttrSec_AutoLayout_Resistance = @"a_r";
SPLKAttrSectionIdentifier const SPLKAttrSec_AutoLayout_Constraints = @"a_c";
SPLKAttrSectionIdentifier const SPLKAttrSec_AutoLayout_IntrinsicSize = @"a_i";

SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_Visibility = @"v_v";
SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_InterationAndMasks = @"v_i";
SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_Corner = @"v_c";
SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_BgColor = @"v_b";
SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_Border = @"v_bo";
SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_Shadow = @"v_s";
SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_ContentMode = @"v_co";
SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_TintColor = @"v_t";
SPLKAttrSectionIdentifier const SPLKAttrSec_ViewLayer_Tag = @"v_ta";

SPLKAttrSectionIdentifier const SPLKAttrSec_UIImageView_Name = @"i_n";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIImageView_Open = @"i_o";

SPLKAttrSectionIdentifier const SPLKAttrSec_UILabel_Text = @"lb_t";
SPLKAttrSectionIdentifier const SPLKAttrSec_UILabel_Font = @"lb_f";
SPLKAttrSectionIdentifier const SPLKAttrSec_UILabel_NumberOfLines = @"lb_n";
SPLKAttrSectionIdentifier const SPLKAttrSec_UILabel_TextColor = @"lb_tc";
SPLKAttrSectionIdentifier const SPLKAttrSec_UILabel_BreakMode = @"lb_b";
SPLKAttrSectionIdentifier const SPLKAttrSec_UILabel_Alignment = @"lb_a";
SPLKAttrSectionIdentifier const SPLKAttrSec_UILabel_CanAdjustFont = @"lb_c";

SPLKAttrSectionIdentifier const SPLKAttrSec_UIControl_EnabledSelected = @"c_e";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIControl_VerAlignment = @"c_v";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIControl_HorAlignment = @"c_h";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIControl_QMUIOutsideEdge = @"c_o";

SPLKAttrSectionIdentifier const SPLKAttrSec_UIButton_ContentInsets = @"b_c";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIButton_TitleInsets = @"b_t";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIButton_ImageInsets = @"b_i";

SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_ContentInset = @"s_c";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_AdjustedInset = @"s_a";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_IndicatorInset = @"s_i";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_Offset = @"s_o";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_ContentSize = @"s_cs";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_Behavior = @"s_b";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_ShowsIndicator = @"s_si";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_Bounce = @"s_bo";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_ScrollPaging = @"s_s";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_ContentTouches = @"s_ct";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_Zoom = @"s_z";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIScrollView_QMUIInitialInset = @"s_ii";

SPLKAttrSectionIdentifier const SPLKAttrSec_UITableView_Style = @"t_s";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITableView_SectionsNumber = @"t_sn";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITableView_RowsNumber = @"t_r";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITableView_SeparatorStyle = @"t_ss";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITableView_SeparatorColor = @"t_sc";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITableView_SeparatorInset = @"t_si";

SPLKAttrSectionIdentifier const SPLKAttrSec_UITextView_Basic = @"tv_b";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextView_Text = @"tv_t";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextView_Font = @"tv_f";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextView_TextColor = @"tv_tc";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextView_Alignment = @"tv_a";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextView_ContainerInset = @"tv_c";

SPLKAttrSectionIdentifier const SPLKAttrSec_UITextField_Text = @"tf_t";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextField_Placeholder = @"tf_p";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextField_Font = @"tf_f";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextField_TextColor = @"tf_tc";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextField_Alignment = @"tf_a";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextField_Clears = @"tf_c";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextField_CanAdjustFont = @"tf_ca";
SPLKAttrSectionIdentifier const SPLKAttrSec_UITextField_ClearButtonMode = @"tf_cb";

SPLKAttrSectionIdentifier const SPLKAttrSec_UIVisualEffectView_Style = @"ve_s";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIVisualEffectView_QMUIForegroundColor = @"ve_f";

SPLKAttrSectionIdentifier const SPLKAttrSec_UIStackView_Axis = @"usv_axis";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIStackView_Distribution = @"usv_dis";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIStackView_Alignment = @"usv_align";
SPLKAttrSectionIdentifier const SPLKAttrSec_UIStackView_Spacing = @"usv_spa";

#pragma mark - Attr

SPLKAttrIdentifier const SPLKAttr_None = @"n";
SPLKAttrIdentifier const SPLKAttr_UserCustom = @"ctm";

SPLKAttrIdentifier const SPLKAttr_Class_Class_Class = @"c_c_c";


SPLKAttrIdentifier const SPLKAttr_Relation_Relation_Relation = @"r_r_r";

SPLKAttrIdentifier const SPLKAttr_Layout_Frame_Frame = @"l_f_f";
SPLKAttrIdentifier const SPLKAttr_Layout_Bounds_Bounds = @"l_b_b";
SPLKAttrIdentifier const SPLKAttr_Layout_SafeArea_SafeArea = @"l_s_s";
SPLKAttrIdentifier const SPLKAttr_Layout_Position_Position = @"l_p_p";
SPLKAttrIdentifier const SPLKAttr_Layout_AnchorPoint_AnchorPoint = @"l_a_a";

SPLKAttrIdentifier const SPLKAttr_AutoLayout_Hugging_Hor = @"al_h_h";
SPLKAttrIdentifier const SPLKAttr_AutoLayout_Hugging_Ver = @"al_h_v";
SPLKAttrIdentifier const SPLKAttr_AutoLayout_Resistance_Hor = @"al_r_h";
SPLKAttrIdentifier const SPLKAttr_AutoLayout_Resistance_Ver = @"al_r_v";
SPLKAttrIdentifier const SPLKAttr_AutoLayout_Constraints_Constraints = @"al_c_c";
SPLKAttrIdentifier const SPLKAttr_AutoLayout_IntrinsicSize_Size = @"cl_i_s";

SPLKAttrIdentifier const SPLKAttr_ViewLayer_Visibility_Hidden = @"vl_v_h";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Visibility_Opacity = @"vl_v_o";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_InterationAndMasks_Interaction = @"vl_i_i";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_InterationAndMasks_MasksToBounds = @"vl_i_m";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Corner_Radius = @"vl_c_r";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_BgColor_BgColor = @"vl_b_b";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Border_Color = @"vl_b_c";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Border_Width = @"vl_b_w";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Shadow_Color = @"vl_s_c";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Shadow_Opacity = @"vl_s_o";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Shadow_Radius = @"vl_s_r";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Shadow_OffsetW = @"vl_s_ow";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Shadow_OffsetH = @"vl_s_oh";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_ContentMode_Mode = @"vl_c_m";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_TintColor_Color = @"vl_t_c";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_TintColor_Mode = @"vl_t_m";
SPLKAttrIdentifier const SPLKAttr_ViewLayer_Tag_Tag = @"vl_t_t";

SPLKAttrIdentifier const SPLKAttr_UIImageView_Name_Name = @"iv_n_n";
SPLKAttrIdentifier const SPLKAttr_UIImageView_Open_Open = @"iv_o_o";

SPLKAttrIdentifier const SPLKAttr_UILabel_Text_Text = @"lb_t_t";
SPLKAttrIdentifier const SPLKAttr_UILabel_Font_Name = @"lb_f_n";
SPLKAttrIdentifier const SPLKAttr_UILabel_Font_Size = @"lb_f_s";
SPLKAttrIdentifier const SPLKAttr_UILabel_NumberOfLines_NumberOfLines = @"lb_n_n";
SPLKAttrIdentifier const SPLKAttr_UILabel_TextColor_Color = @"lb_t_c";
SPLKAttrIdentifier const SPLKAttr_UILabel_Alignment_Alignment = @"lb_a_a";
SPLKAttrIdentifier const SPLKAttr_UILabel_BreakMode_Mode = @"lb_b_m";
SPLKAttrIdentifier const SPLKAttr_UILabel_CanAdjustFont_CanAdjustFont = @"lb_c_c";

SPLKAttrIdentifier const SPLKAttr_UIControl_EnabledSelected_Enabled = @"ct_e_e";
SPLKAttrIdentifier const SPLKAttr_UIControl_EnabledSelected_Selected = @"ct_e_s";
SPLKAttrIdentifier const SPLKAttr_UIControl_VerAlignment_Alignment = @"ct_v_a";
SPLKAttrIdentifier const SPLKAttr_UIControl_HorAlignment_Alignment = @"ct_h_a";
SPLKAttrIdentifier const SPLKAttr_UIControl_QMUIOutsideEdge_Edge = @"ct_o_e";

SPLKAttrIdentifier const SPLKAttr_UIButton_ContentInsets_Insets = @"bt_c_i";
SPLKAttrIdentifier const SPLKAttr_UIButton_TitleInsets_Insets = @"bt_t_i";
SPLKAttrIdentifier const SPLKAttr_UIButton_ImageInsets_Insets = @"bt_i_i";

SPLKAttrIdentifier const SPLKAttr_UIScrollView_Offset_Offset = @"sv_o_o";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_ContentSize_Size = @"sv_c_s";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_ContentInset_Inset = @"sv_c_i";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_AdjustedInset_Inset = @"sv_a_i";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_Behavior_Behavior = @"sv_b_b";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_IndicatorInset_Inset = @"sv_i_i";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_ScrollPaging_ScrollEnabled = @"sv_s_s";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_ScrollPaging_PagingEnabled = @"sv_s_p";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_Bounce_Ver = @"sv_b_v";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_Bounce_Hor = @"sv_b_h";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_ShowsIndicator_Hor = @"sv_h_h";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_ShowsIndicator_Ver = @"sv_s_v";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_ContentTouches_Delay = @"sv_c_d";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_ContentTouches_CanCancel = @"sv_c_c";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_Zoom_MinScale = @"sv_z_mi";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_Zoom_MaxScale = @"sv_z_ma";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_Zoom_Scale = @"sv_z_s";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_Zoom_Bounce = @"sv_z_b";
SPLKAttrIdentifier const SPLKAttr_UIScrollView_QMUIInitialInset_Inset = @"sv_qi_i";

SPLKAttrIdentifier const SPLKAttr_UITableView_Style_Style = @"tv_s_s";
SPLKAttrIdentifier const SPLKAttr_UITableView_SectionsNumber_Number = @"tv_s_n";
SPLKAttrIdentifier const SPLKAttr_UITableView_RowsNumber_Number = @"tv_r_n";
SPLKAttrIdentifier const SPLKAttr_UITableView_SeparatorInset_Inset = @"tv_s_i";
SPLKAttrIdentifier const SPLKAttr_UITableView_SeparatorColor_Color = @"tv_s_c";
SPLKAttrIdentifier const SPLKAttr_UITableView_SeparatorStyle_Style = @"tv_ss_s";

SPLKAttrIdentifier const SPLKAttr_UITextView_Font_Name = @"te_f_n";
SPLKAttrIdentifier const SPLKAttr_UITextView_Font_Size = @"te_f_s";
SPLKAttrIdentifier const SPLKAttr_UITextView_Basic_Editable = @"te_b_e";
SPLKAttrIdentifier const SPLKAttr_UITextView_Basic_Selectable = @"te_b_s";
SPLKAttrIdentifier const SPLKAttr_UITextView_Text_Text = @"te_t_t";
SPLKAttrIdentifier const SPLKAttr_UITextView_TextColor_Color = @"te_t_c";
SPLKAttrIdentifier const SPLKAttr_UITextView_Alignment_Alignment = @"te_a_a";
SPLKAttrIdentifier const SPLKAttr_UITextView_ContainerInset_Inset = @"te_c_i";

SPLKAttrIdentifier const SPLKAttr_UITextField_Text_Text = @"tf_t_t";
SPLKAttrIdentifier const SPLKAttr_UITextField_Placeholder_Placeholder = @"tf_p_p";
SPLKAttrIdentifier const SPLKAttr_UITextField_Font_Name = @"tf_f_n";
SPLKAttrIdentifier const SPLKAttr_UITextField_Font_Size = @"tf_f_s";
SPLKAttrIdentifier const SPLKAttr_UITextField_TextColor_Color = @"tf_t_c";
SPLKAttrIdentifier const SPLKAttr_UITextField_Alignment_Alignment = @"tf_a_a";
SPLKAttrIdentifier const SPLKAttr_UITextField_Clears_ClearsOnBeginEditing = @"tf_c_c";
SPLKAttrIdentifier const SPLKAttr_UITextField_Clears_ClearsOnInsertion = @"tf_c_co";
SPLKAttrIdentifier const SPLKAttr_UITextField_CanAdjustFont_CanAdjustFont = @"tf_c_ca";
SPLKAttrIdentifier const SPLKAttr_UITextField_CanAdjustFont_MinSize = @"tf_c_m";
SPLKAttrIdentifier const SPLKAttr_UITextField_ClearButtonMode_Mode = @"tf_cb_m";

SPLKAttrIdentifier const SPLKAttr_UIVisualEffectView_Style_Style = @"ve_s_s";
SPLKAttrIdentifier const SPLKAttr_UIVisualEffectView_QMUIForegroundColor_Color = @"ve_f_c";

SPLKAttrIdentifier const SPLKAttr_UIStackView_Axis_Axis = @"usv_axis_axis";
SPLKAttrIdentifier const SPLKAttr_UIStackView_Distribution_Distribution = @"usv_dis_dis";
SPLKAttrIdentifier const SPLKAttr_UIStackView_Alignment_Alignment = @"usv_ali_ali";
SPLKAttrIdentifier const SPLKAttr_UIStackView_Spacing_Spacing = @"usv_spa_spa";

#endif /* SHOULD_COMPILE_SPLK_SHARED */
