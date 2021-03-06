(*  Title:       First-Order Ordered Resolution Calculus with Selection
    Author:      Anders Schlichtkrull <andschl at dtu.dk>, 2016, 2017
    Author:      Jasmin Blanchette <j.c.blanchette at vu.nl>, 2014, 2017
    Author:      Dmitriy Traytel <traytel at inf.ethz.ch>, 2014
    Maintainer:  Anders Schlichtkrull <andschl at dtu.dk>
*)

section \<open>First-Order Ordered Resolution Calculus with Selection\<close>

theory FO_Ordered_Resolution
  imports Abstract_Substitution Ordered_Ground_Resolution Standard_Redundancy
begin

text \<open>
This material is based on Section 4.3 (``A Simple Resolution Prover for First-Order Clauses'') of
Bachmair and Ganzinger's chapter. Specifically, it formalizes the ordered resolution calculus for
first-order standard clauses presented in Figure 4 and its related lemmas and theorems, including
soundness and Lemma 4.12 (the lifting lemma).

The following corresponds to pages 41--42 of Section 4.3, until Figure 5 and its explanation.
\<close>

locale FO_resolution = mgu subst_atm id_subst comp_subst atm_of_atms renamings_apart mgu
  for
    subst_atm :: "'a :: wellorder \<Rightarrow> 's \<Rightarrow> 'a" and
    id_subst :: "'s" and
    comp_subst :: "'s \<Rightarrow> 's \<Rightarrow> 's" and
    renamings_apart :: "'a literal multiset list \<Rightarrow> 's list" and
    atm_of_atms :: "'a list \<Rightarrow> 'a" and
    mgu :: "'a set set \<Rightarrow> 's option" +
  fixes
    less_atm :: "'a \<Rightarrow> 'a \<Rightarrow> bool"
  assumes
    less_atm_stable: "less_atm A B \<Longrightarrow> less_atm (A \<cdot>a \<sigma>) (B \<cdot>a \<sigma>)"
begin


subsection \<open>Library\<close>

lemma Bex_cartesian_product: "(\<exists>xy \<in> A \<times> B. P xy) \<equiv> (\<exists>x \<in> A. \<exists>y \<in> B. P (x, y))"
  by simp

(* FIXME: Move to "Multiset.thy" *)
lemma length_sorted_list_of_multiset[simp]: "length (sorted_list_of_multiset A) = size A"
  by (metis mset_sorted_list_of_multiset size_mset)

(* FIXME: move? or avoid? *)
lemma eql_map_neg_lit_eql_atm:
  assumes "map (\<lambda>L. L \<cdot>l \<eta>) (map Neg As') = map Neg As"
  shows "As' \<cdot>al \<eta> = As"
  using assms by (induction As' arbitrary: As) auto

lemma instance_list:
  assumes "negs (mset As) = SDA' \<cdot> \<eta>"
  shows "\<exists>As'. negs (mset As') = SDA' \<and> As' \<cdot>al \<eta> = As"
proof -
  from assms have negL: "\<forall>L \<in># SDA'. is_neg L"
    using Melem_subst_cls subst_lit_in_negs_is_neg by metis

  from assms have "{#L \<cdot>l \<eta>. L \<in># SDA'#} = mset (map Neg As)"
    using subst_cls_def by auto
  then have "\<exists>NAs'. map (\<lambda>L. L \<cdot>l \<eta>) NAs' = map Neg As \<and> mset NAs' = SDA'"
    using image_mset_of_subset_list[of "\<lambda>L. L \<cdot>l \<eta>" SDA' "map Neg As"] by auto
  then obtain As' where As'_p:
    "map (\<lambda>L. L \<cdot>l \<eta>) (map Neg As') = map Neg As \<and> mset (map Neg As') = SDA'"
    by (metis (no_types, lifting) Neg_atm_of_iff negL ex_map_conv set_mset_mset)

  have "negs (mset As') = SDA'"
    using As'_p by auto
  moreover have "map (\<lambda>L. L \<cdot>l \<eta>) (map Neg As') = map Neg As"
    using As'_p by auto
  then have "As' \<cdot>al \<eta> = As"
    using eql_map_neg_lit_eql_atm by auto
  ultimately show ?thesis
    by blast
qed


subsection \<open>First-Order Logic\<close>

inductive true_fo_cls :: "'a interp \<Rightarrow> 'a clause \<Rightarrow> bool" (infix "\<Turnstile>fo" 50) where
  true_fo_cls: "(\<And>\<sigma>. is_ground_subst \<sigma> \<Longrightarrow> I \<Turnstile> C \<cdot> \<sigma>) \<Longrightarrow> I \<Turnstile>fo C"

lemma true_fo_cls_inst: "I \<Turnstile>fo C \<Longrightarrow> is_ground_subst \<sigma> \<Longrightarrow> I \<Turnstile> C \<cdot> \<sigma>"
  by (rule true_fo_cls.induct)

inductive true_fo_cls_mset :: "'a interp \<Rightarrow> 'a clause multiset \<Rightarrow> bool" (infix "\<Turnstile>fom" 50) where
  true_fo_cls_mset: "(\<And>\<sigma>. is_ground_subst \<sigma> \<Longrightarrow> I \<Turnstile>m CC \<cdot>cm \<sigma>) \<Longrightarrow> I \<Turnstile>fom CC"

lemma true_fo_cls_mset_inst: "I \<Turnstile>fom C \<Longrightarrow> is_ground_subst \<sigma> \<Longrightarrow> I \<Turnstile>m C \<cdot>cm \<sigma>"
  by (rule true_fo_cls_mset.induct)

lemma true_fo_cls_mset_def2: "I \<Turnstile>fom CC \<longleftrightarrow> (\<forall>C \<in># CC. I \<Turnstile>fo C)"
  unfolding true_fo_cls_mset.simps true_fo_cls.simps true_cls_mset_def by force

context
  fixes S :: "'a clause \<Rightarrow> 'a clause"
begin


subsection \<open>Calculus\<close>

text \<open>
The following corresponds to Figure 4.
\<close>

definition maximal_wrt :: "'a \<Rightarrow> 'a literal multiset \<Rightarrow> bool" where
  "maximal_wrt A C \<longleftrightarrow> (\<forall>B \<in> atms_of C. \<not> less_atm A B)"

definition strictly_maximal_wrt :: "'a \<Rightarrow> 'a literal multiset \<Rightarrow> bool" where
  "strictly_maximal_wrt A C \<equiv> \<forall>B \<in> atms_of C. A \<noteq> B \<and> \<not> less_atm A B"

lemma strictly_maximal_wrt_maximal_wrt: "strictly_maximal_wrt A C \<Longrightarrow> maximal_wrt A C"
  unfolding maximal_wrt_def strictly_maximal_wrt_def by auto

(* FIXME: use hd instead of ! 0 *)
inductive eligible :: "'s \<Rightarrow> 'a list \<Rightarrow> 'a clause \<Rightarrow> bool" where
  eligible:
    "S DA = negs (mset As) \<or> S DA = {#} \<and> length As = 1 \<and> maximal_wrt (As ! 0 \<cdot>a \<sigma>) (DA \<cdot> \<sigma>) \<Longrightarrow>
     eligible \<sigma> As DA"

inductive
  ord_resolve
  :: "'a clause list \<Rightarrow> 'a clause \<Rightarrow> 'a multiset list \<Rightarrow> 'a list \<Rightarrow> 's \<Rightarrow> 'a clause \<Rightarrow> bool"
where
  ord_resolve:
    "length CAs = n \<Longrightarrow>
     length Cs = n \<Longrightarrow>
     length AAs = n \<Longrightarrow>
     length As = n \<Longrightarrow>
     n \<noteq> 0 \<Longrightarrow>
     (\<forall>i < n. CAs ! i = Cs ! i + poss (AAs ! i)) \<Longrightarrow>
     (\<forall>i < n. AAs ! i \<noteq> {#}) \<Longrightarrow>
     Some \<sigma> = mgu (set_mset ` set (map2 add_mset As AAs)) \<Longrightarrow>
     eligible \<sigma> As (D + negs (mset As)) \<Longrightarrow>
     (\<forall>i < n. strictly_maximal_wrt (As ! i \<cdot>a \<sigma>) (Cs ! i \<cdot> \<sigma>)) \<Longrightarrow>
     (\<forall>i < n. S (CAs ! i) = {#}) \<Longrightarrow>
     ord_resolve CAs (D + negs (mset As)) AAs As \<sigma> (((\<Union># mset Cs) + D) \<cdot> \<sigma>)"

inductive
  ord_resolve_rename
  :: "'a clause list \<Rightarrow> 'a clause \<Rightarrow> 'a multiset list \<Rightarrow> 'a list \<Rightarrow> 's \<Rightarrow> 'a clause \<Rightarrow> bool"
where
  ord_resolve_rename:
    "length CAs = n \<Longrightarrow>
     length AAs = n \<Longrightarrow>
     length As = n \<Longrightarrow>
     (\<forall>i < n. poss (AAs ! i) \<subseteq># CAs ! i) \<Longrightarrow>
     negs (mset As) \<subseteq># DA \<Longrightarrow>
     \<rho> = hd (renamings_apart (DA # CAs)) \<Longrightarrow>
     \<rho>s = tl (renamings_apart (DA # CAs)) \<Longrightarrow>
     ord_resolve (CAs \<cdot>\<cdot>cl \<rho>s) (DA \<cdot> \<rho>) (AAs \<cdot>\<cdot>aml \<rho>s) (As \<cdot>al \<rho>) \<sigma> E \<Longrightarrow>
     ord_resolve_rename CAs DA AAs As \<sigma> E"

lemma ord_resolve_empty_main_prem: "\<not> ord_resolve Cs {#} AAs As \<sigma> E"
  by (simp add: ord_resolve.simps)

lemma ord_resolve_rename_empty_main_prem: "\<not> ord_resolve_rename Cs {#} AAs As \<sigma> E"
  by (simp add: ord_resolve_empty_main_prem ord_resolve_rename.simps)


subsection \<open>Soundness\<close>

text \<open>
Soundness is not discussed in the chapter, but it is an important property. The following lemma is
used to prove soundness. It is also used to prove Lemma 4.10, which is used to prove completeness.
\<close>

lemma ord_resolve_ground_inst_sound:
  assumes
    res_e: "ord_resolve CAs DA AAs As \<sigma> E" and
    cc_inst_true: "I \<Turnstile>m mset CAs \<cdot>cm \<sigma> \<cdot>cm \<eta>" and
    d_inst_true: "I \<Turnstile> DA \<cdot> \<sigma> \<cdot> \<eta>" and
    ground_subst_\<eta>: "is_ground_subst \<eta>"
  shows "I \<Turnstile> E \<cdot> \<eta>"
  using res_e
proof (cases rule: ord_resolve.cases)
  case (ord_resolve n Cs D)
  note da = this(1) and e = this(2) and cas_len = this(3) and cs_len = this(4) and
    aas_len = this(5) and as_len = this(6) and cas = this(8) and mgu = this(10) and
    len = this(1)

  have len: "length CAs = length As"
    using as_len cas_len by auto
  have "is_ground_subst (\<sigma> \<odot> \<eta>)"
    using ground_subst_\<eta> by (rule is_ground_comp_subst)
  then have cc_true: "I \<Turnstile>m mset CAs \<cdot>cm \<sigma> \<cdot>cm \<eta>" and d_true: "I \<Turnstile> DA \<cdot> \<sigma> \<cdot> \<eta>"
    using cc_inst_true d_inst_true by auto

  from mgu have unif: "\<forall>i < n. \<forall>A\<in>#AAs ! i. A \<cdot>a \<sigma> = As ! i \<cdot>a \<sigma>"
    using mgu_unifier as_len aas_len by blast

  show "I \<Turnstile> E \<cdot> \<eta>"
  proof (cases "\<forall>A \<in> set As. A \<cdot>a \<sigma> \<cdot>a \<eta> \<in> I")
    case True
    then have "\<not> I \<Turnstile> negs (mset As) \<cdot> \<sigma> \<cdot> \<eta>"
      unfolding true_cls_def[of I] by auto
    then have "I \<Turnstile> D \<cdot> \<sigma> \<cdot> \<eta>"
      using d_true da by auto
    then show ?thesis
      unfolding e by auto
  next
    case False
    then obtain i where a_in_aa: "i < length CAs" and a_false: "(As ! i) \<cdot>a \<sigma> \<cdot>a \<eta> \<notin> I"
      using da len by (metis in_set_conv_nth)
    define C where "C \<equiv> Cs ! i"
    define BB where "BB \<equiv> AAs ! i"
    have c_cf': "C \<subseteq># \<Union># mset CAs"
      unfolding C_def using a_in_aa cas cas_len
      by (metis less_subset_eq_Union_mset mset_subset_eq_add_left subset_mset.order.trans)
    have c_in_cc: "C + poss BB \<in># mset CAs"
      using C_def BB_def a_in_aa cas_len in_set_conv_nth cas by fastforce
    {
      fix B
      assume "B \<in># BB"
      then have "B \<cdot>a \<sigma> = (As ! i) \<cdot>a \<sigma>"
        using unif a_in_aa cas_len unfolding BB_def by auto
    }
    then have "\<not> I \<Turnstile> poss BB \<cdot> \<sigma> \<cdot> \<eta>"
      using a_false by (auto simp: true_cls_def)
    moreover have "I \<Turnstile> (C + poss BB) \<cdot> \<sigma> \<cdot> \<eta>"
      using c_in_cc cc_true true_cls_mset_true_cls[of I "mset CAs \<cdot>cm \<sigma> \<cdot>cm \<eta>"] by force
    ultimately have "I \<Turnstile> C \<cdot> \<sigma> \<cdot> \<eta>"
      by simp
    then show ?thesis
      unfolding e subst_cls_union using c_cf' C_def a_in_aa cas_len cs_len
      by (metis (no_types, lifting) mset_subset_eq_add_left nth_mem_mset set_mset_mono sum_mset.remove true_cls_mono subst_cls_mono)
  qed
qed

lemma ord_resolve_sound:
  assumes
    res_e: "ord_resolve CAs DA AAs As \<sigma> E" and
    cc_d_true: "I \<Turnstile>fom mset CAs + {#DA#}"
  shows "I \<Turnstile>fo E"
proof (rule true_fo_cls, use res_e in \<open>cases rule: ord_resolve.cases\<close>)
  fix \<eta>
  assume ground_subst_\<eta>: "is_ground_subst \<eta>"
  case (ord_resolve n Cs D)
  note da = this(1) and e = this(2) and cas_len = this(3) and cs_len = this(4)
    and aas_len = this(5) and as_len = this(6) and cas = this(8) and mgu = this(10)

  have "is_ground_subst (\<sigma> \<odot> \<eta>)"
    using ground_subst_\<eta> by (rule is_ground_comp_subst)
  then have cas_true: "I \<Turnstile>m mset CAs \<cdot>cm \<sigma> \<cdot>cm \<eta>" and da_true: "I \<Turnstile> DA \<cdot> \<sigma> \<cdot> \<eta>"
    using true_fo_cls_mset_inst[OF cc_d_true, of "\<sigma> \<odot> \<eta>"] by auto
  show "I \<Turnstile> E \<cdot> \<eta>"
    using ord_resolve_ground_inst_sound[OF res_e cas_true da_true] ground_subst_\<eta> by auto
qed

lemma subst_sound: "I \<Turnstile>fo C \<Longrightarrow> I \<Turnstile>fo (C \<cdot> \<rho>)"
  by (metis is_ground_comp_subst subst_cls_comp_subst true_fo_cls true_fo_cls_inst)

lemma true_fo_cls_mset_true_fo_cls: "I \<Turnstile>fom CC \<Longrightarrow> C \<in># CC \<Longrightarrow> I \<Turnstile>fo C"
  using true_fo_cls_mset_def2 by auto

lemma subst_sound_scl:
  assumes
    len: "length P = length CAs" and
    true_cas: "I \<Turnstile>fom mset CAs"
  shows "I \<Turnstile>fom mset (CAs \<cdot>\<cdot>cl P)"
proof -
  from true_cas have "\<forall>CA. CA\<in># mset CAs \<longrightarrow> I \<Turnstile>fo CA"
    using true_fo_cls_mset_true_fo_cls by auto
  then have "\<forall>i < length CAs. I \<Turnstile>fo CAs ! i"
    using in_set_conv_nth by auto
  then have true_cp: "\<forall>i < length CAs. I \<Turnstile>fo CAs ! i \<cdot> P ! i"
    using subst_sound len by auto

  {
    fix CA
    assume "CA \<in># mset (CAs \<cdot>\<cdot>cl P)"
    then obtain i where
      i_x: "i < length (CAs \<cdot>\<cdot>cl P)" "CA = (CAs \<cdot>\<cdot>cl P) ! i"
      by (metis in_mset_conv_nth)
    then have "I \<Turnstile>fo CA"
      using true_cp unfolding subst_cls_lists_def by (simp add: len)
  }
  then show ?thesis
    unfolding true_fo_cls_mset_def2 by auto
qed

text \<open>
This is a lemma needed to prove Lemma 4.11.
\<close>

lemma ord_resolve_rename_ground_inst_sound:
  assumes
    "ord_resolve_rename CAs DA AAs As \<sigma> E" and
    "\<rho>s = tl (renamings_apart (DA # CAs))" and
    "\<rho> = hd (renamings_apart (DA # CAs))" and
    "I \<Turnstile>m (mset (CAs \<cdot>\<cdot>cl \<rho>s)) \<cdot>cm \<sigma> \<cdot>cm \<eta>" and
    "I \<Turnstile> DA \<cdot> \<rho> \<cdot> \<sigma> \<cdot> \<eta>" and
    "is_ground_subst \<eta>"
  shows "I \<Turnstile> E \<cdot> \<eta>"
  using assms by (cases rule: ord_resolve_rename.cases) (fast intro: ord_resolve_ground_inst_sound)

lemma ord_resolve_rename_sound:
  assumes
    res_e: "ord_resolve_rename CAs DA AAs As \<sigma> E" and
    cc_d_true: "I \<Turnstile>fom (mset CAs) + {#DA#}"
  shows "I \<Turnstile>fo E"
  using res_e
proof (cases rule: ord_resolve_rename.cases)
  case (ord_resolve_rename n \<rho> \<rho>s)
  note \<rho>s = this(7) and res = this(8)
  have len: "length \<rho>s = length CAs"
    using \<rho>s renames_apart by auto
  have "I \<Turnstile>fom mset (CAs \<cdot>\<cdot>cl \<rho>s) + {#DA \<cdot> \<rho>#}"
    using subst_sound_scl[OF len, of I] subst_sound cc_d_true by (simp add: true_fo_cls_mset_def2)
  then show "I \<Turnstile>fo E"
    using ord_resolve_sound[OF res] by simp
qed


subsection \<open>Other Basic Properties\<close>

lemma ord_resolve_unique:
  assumes
    "ord_resolve CAs DA AAs As \<sigma> E" and
    "ord_resolve CAs DA AAs As \<sigma>' E'"
  shows "\<sigma> = \<sigma>' \<and> E = E'"
  using assms
proof (cases rule: ord_resolve.cases[case_product ord_resolve.cases], intro conjI)
  case (ord_resolve_ord_resolve CAs n Cs AAs As \<sigma>'' DA CAs' n' Cs' AAs' As' \<sigma>''' DA')
  note res = this(1-17) and res' = this(18-34)

  show \<sigma>: "\<sigma> = \<sigma>'"
    using res(3-5,14) res'(3-5,14) by (metis option.inject)

  have "Cs = Cs'"
    using res(1,3,7,8,12) res'(1,3,7,8,12) by (metis add_right_imp_eq nth_equalityI)
  moreover have "DA = DA'"
    using res(2,4) res'(2,4) by fastforce
  ultimately show "E = E'"
    using res(5,6) res'(5,6) \<sigma> by blast
qed

lemma ord_resolve_rename_unique:
  assumes
    "ord_resolve_rename CAs DA AAs As \<sigma> E" and
    "ord_resolve_rename CAs DA AAs As \<sigma>' E'"
  shows "\<sigma> = \<sigma>' \<and> E = E'"
  using assms unfolding ord_resolve_rename.simps using ord_resolve_unique by meson

lemma ord_resolve_max_side_prems: "ord_resolve CAs DA AAs As \<sigma> E \<Longrightarrow> length CAs \<le> size DA"
  by (auto elim!: ord_resolve.cases)

lemma ord_resolve_rename_max_side_prems:
  "ord_resolve_rename CAs DA AAs As \<sigma> E \<Longrightarrow> length CAs \<le> size DA"
  by (elim ord_resolve_rename.cases, drule ord_resolve_max_side_prems, simp add: renames_apart)


subsection \<open>Inference System\<close>

definition ord_FO_\<Gamma> :: "'a inference set" where
  "ord_FO_\<Gamma> = {Infer (mset CAs) DA E | CAs DA AAs As \<sigma> E. ord_resolve_rename CAs DA AAs As \<sigma> E}"

interpretation ord_FO_resolution: inference_system ord_FO_\<Gamma> .

lemma exists_compose: "\<exists>x. P (f x) \<Longrightarrow> \<exists>y. P y"
  by meson

lemma finite_ord_FO_resolution_inferences_between:
  assumes fin_cc: "finite CC"
  shows "finite (ord_FO_resolution.inferences_between CC C)"
proof -
  let ?CCC = "CC \<union> {C}"

  define all_AA where "all_AA = (\<Union>D \<in> ?CCC. atms_of D)"
  define max_ary where "max_ary = Max (size ` ?CCC)"
  define CAS where "CAS = {CAs. CAs \<in> lists ?CCC \<and> length CAs \<le> max_ary}"
  define AS where "AS = {As. As \<in> lists all_AA \<and> length As \<le> max_ary}"
  define AAS where "AAS = {AAs. AAs \<in> lists (mset ` AS) \<and> length AAs \<le> max_ary}"

  note defs = all_AA_def max_ary_def CAS_def AS_def AAS_def

  let ?infer_of =
    "\<lambda>CAs DA AAs As. Infer (mset CAs) DA (THE E. \<exists>\<sigma>. ord_resolve_rename CAs DA AAs As \<sigma> E)"

  let ?Z = "{\<gamma> | CAs DA AAs As \<sigma> E \<gamma>. \<gamma> = Infer (mset CAs) DA E
    \<and> ord_resolve_rename CAs DA AAs As \<sigma> E \<and> infer_from ?CCC \<gamma> \<and> C \<in># prems_of \<gamma>}"
  let ?Y = "{Infer (mset CAs) DA E | CAs DA AAs As \<sigma> E.
    ord_resolve_rename CAs DA AAs As \<sigma> E \<and> set CAs \<union> {DA} \<subseteq> ?CCC}"
  let ?X = "{?infer_of CAs DA AAs As | CAs DA AAs As. CAs \<in> CAS \<and> DA \<in> ?CCC \<and> AAs \<in> AAS \<and> As \<in> AS}"
  let ?W = "CAS \<times> ?CCC \<times> AAS \<times> AS"

  have fin_w: "finite ?W"
    unfolding defs using fin_cc by (simp add: finite_lists_length_le lists_eq_set)

  have "?Z \<subseteq> ?Y"
    by (force simp: infer_from_def)
  also have "\<dots> \<subseteq> ?X"
  proof -
    {
      fix CAs DA AAs As \<sigma> E
      assume
        res_e: "ord_resolve_rename CAs DA AAs As \<sigma> E" and
        da_in: "DA \<in> ?CCC" and
        cas_sub: "set CAs \<subseteq> ?CCC"

      have "E = (THE E. \<exists>\<sigma>. ord_resolve_rename CAs DA AAs As \<sigma> E)
        \<and> CAs \<in> CAS \<and> AAs \<in> AAS \<and> As \<in> AS" (is "?e \<and> ?cas \<and> ?aas \<and> ?as")
      proof (intro conjI)
        show ?e
          using res_e ord_resolve_rename_unique by (blast intro: the_equality[symmetric])
      next
        show ?cas
          unfolding CAS_def max_ary_def using cas_sub
            ord_resolve_rename_max_side_prems[OF res_e] da_in fin_cc
          by (auto simp add: Max_ge_iff)
      next
        show ?aas
          using res_e
        proof (cases rule: ord_resolve_rename.cases)
          case (ord_resolve_rename n \<rho> \<rho>s)
          note len_cas = this(1) and len_aas = this(2) and len_as = this(3) and
            aas_sub = this(4) and as_sub = this(5) and res_e' = this(8)

          show ?thesis
            unfolding AAS_def
          proof (clarify, intro conjI)
            show "AAs \<in> lists (mset ` AS)"
              unfolding AS_def image_def
            proof clarsimp
              fix AA
              assume "AA \<in> set AAs"
              then obtain i where
                i_lt: "i < n" and
                aa: "AA = AAs ! i"
                by (metis in_set_conv_nth len_aas)

              have casi_in: "CAs ! i \<in> ?CCC"
                using i_lt len_cas cas_sub nth_mem by blast

              have pos_aa_sub: "poss AA \<subseteq># CAs ! i"
                using aa aas_sub i_lt by blast
              then have "set_mset AA \<subseteq> atms_of (CAs ! i)"
                by (metis atms_of_poss lits_subseteq_imp_atms_subseteq set_mset_mono)
              also have aa_sub: "\<dots> \<subseteq> all_AA"
                unfolding all_AA_def using casi_in by force
              finally have aa_sub: "set_mset AA \<subseteq> all_AA"
                .

              have "size AA = size (poss AA)"
                by simp
              also have "\<dots> \<le> size (CAs ! i)"
                by (rule size_mset_mono[OF pos_aa_sub])
              also have "\<dots> \<le> max_ary"
                unfolding max_ary_def using fin_cc casi_in by auto
              finally have sz_aa: "size AA \<le> max_ary"
                .

              let ?As' = "sorted_list_of_multiset AA"

              have "?As' \<in> lists all_AA"
                using aa_sub by auto
              moreover have "length ?As' \<le> max_ary"
                using sz_aa by simp
              moreover have "AA = mset ?As'"
                by simp
              ultimately show "\<exists>xa. xa \<in> lists all_AA \<and> length xa \<le> max_ary \<and> AA = mset xa"
                by blast
            qed
          next
            have "length AAs = length As"
              unfolding len_aas len_as ..
            also have "\<dots> \<le> size DA"
              using as_sub size_mset_mono by fastforce
            also have "\<dots> \<le> max_ary"
              unfolding max_ary_def using fin_cc da_in by auto
            finally show "length AAs \<le> max_ary"
              .
          qed
        qed
      next
        show ?as
          unfolding AS_def
        proof (clarify, intro conjI)
          have "set As \<subseteq> atms_of DA"
            using res_e[simplified ord_resolve_rename.simps]
            by (metis atms_of_negs lits_subseteq_imp_atms_subseteq set_mset_mono set_mset_mset)
          also have "\<dots> \<subseteq> all_AA"
            unfolding all_AA_def using da_in by blast
          finally show "As \<in> lists all_AA"
            unfolding lists_eq_set by simp
        next
          have "length As \<le> size DA"
            using res_e[simplified ord_resolve_rename.simps]
              ord_resolve_rename_max_side_prems[OF res_e] by auto
          also have "size DA \<le> max_ary"
            unfolding max_ary_def using fin_cc da_in by auto
          finally show "length As \<le> max_ary"
            .
        qed
      qed
    }
    then show ?thesis
      by simp fast
  qed
  also have "\<dots> \<subseteq> (\<lambda>(CAs, DA, AAs, As). ?infer_of CAs DA AAs As) ` ?W"
    unfolding image_def Bex_cartesian_product by fast
  finally show ?thesis
    unfolding inference_system.inferences_between_def ord_FO_\<Gamma>_def mem_Collect_eq
    by (fast intro: rev_finite_subset[OF finite_imageI[OF fin_w]])
qed

lemma ord_FO_resolution_inferences_between_empty_empty:
  "ord_FO_resolution.inferences_between {} {#} = {}"
  unfolding ord_FO_resolution.inferences_between_def inference_system.inferences_between_def
    infer_from_def ord_FO_\<Gamma>_def
  using ord_resolve_rename_empty_main_prem by auto


subsection \<open>Lifting\<close>

text \<open>
The following corresponds to the passage between Lemmas 4.11 and 4.12.
\<close>

context
  fixes M :: "'a clause set"
  assumes select: "selection S"
begin

interpretation selection
  by (rule select)

definition S_M :: "'a literal multiset \<Rightarrow> 'a literal multiset" where
  "S_M C =
   (if C \<in> grounding_of_clss M then
      (SOME C'. \<exists>D \<sigma>. D \<in> M \<and> C = D \<cdot> \<sigma> \<and> C' = S D \<cdot> \<sigma> \<and> is_ground_subst \<sigma>)
    else
      S C)"

lemma S_M_grounding_of_clss:
  assumes "C \<in> grounding_of_clss M"
  obtains D \<sigma> where
    "D \<in> M \<and> C = D \<cdot> \<sigma> \<and> S_M C = S D \<cdot> \<sigma> \<and> is_ground_subst \<sigma>"
proof (atomize_elim, unfold S_M_def eqTrueI[OF assms] if_True, rule someI_ex)
  from assms show "\<exists>C' D \<sigma>. D \<in> M \<and> C = D \<cdot> \<sigma> \<and> C' = S D \<cdot> \<sigma> \<and> is_ground_subst \<sigma>"
    by (auto simp: grounding_of_clss_def grounding_of_cls_def)
qed

lemma S_M_not_grounding_of_clss: "C \<notin> grounding_of_clss M \<Longrightarrow> S_M C = S C"
  unfolding S_M_def by simp

lemma S_M_selects_subseteq: "S_M C \<subseteq># C"
  by (metis S_M_grounding_of_clss S_M_not_grounding_of_clss S_selects_subseteq subst_cls_mono_mset)

lemma S_M_selects_neg_lits: "L \<in># S_M C \<Longrightarrow> is_neg L"
  by (metis Melem_subst_cls S_M_grounding_of_clss S_M_not_grounding_of_clss S_selects_neg_lits
      subst_lit_is_neg)

end

end

text \<open>
The following corresponds to Lemma 4.12:
\<close>

lemma map2_add_mset_map:
  assumes "length AAs' = n" and "length As' = n"
  shows "map2 add_mset (As' \<cdot>al \<eta>) (AAs' \<cdot>aml \<eta>) = map2 add_mset As' AAs' \<cdot>aml \<eta>"
  using assms
proof (induction n arbitrary: AAs' As')
  case (Suc n)
  then have "map2 add_mset (tl (As' \<cdot>al \<eta>)) (tl (AAs' \<cdot>aml \<eta>)) = map2 add_mset (tl As') (tl AAs') \<cdot>aml \<eta>"
    by simp
  moreover
  have Succ: "length (As' \<cdot>al \<eta>) = Suc n" "length (AAs' \<cdot>aml \<eta>) = Suc n"
    using Suc(3) Suc(2) by auto
  then have "length (tl (As' \<cdot>al \<eta>)) = n" "length (tl (AAs' \<cdot>aml \<eta>)) = n"
    by auto
  then have "length (map2 add_mset (tl (As' \<cdot>al \<eta>)) (tl (AAs' \<cdot>aml \<eta>))) = n"
    "length (map2 add_mset (tl As') (tl AAs') \<cdot>aml \<eta>) = n"
    using Suc(2,3) by auto
  ultimately have "\<forall>i < n. tl (map2 add_mset ( (As' \<cdot>al \<eta>)) ((AAs' \<cdot>aml \<eta>))) ! i =
    tl (map2 add_mset (As') (AAs') \<cdot>aml \<eta>) ! i"
    using Suc(2,3) Succ by (simp add: map2_tl map_tl subst_atm_mset_list_def del: subst_atm_list_tl)
  moreover have nn: "length (map2 add_mset ((As' \<cdot>al \<eta>)) ((AAs' \<cdot>aml \<eta>))) = Suc n"
    "length (map2 add_mset (As') (AAs') \<cdot>aml \<eta>) = Suc n"
    using Succ Suc by auto
  ultimately have "\<forall>i. i < Suc n \<longrightarrow> i > 0 \<longrightarrow>
    map2 add_mset (As' \<cdot>al \<eta>) (AAs' \<cdot>aml \<eta>) ! i = (map2 add_mset As' AAs' \<cdot>aml \<eta>) ! i"
    by (auto simp: subst_atm_mset_list_def gr0_conv_Suc subst_atm_mset_def)
  moreover have "add_mset (hd As' \<cdot>a \<eta>) (hd AAs' \<cdot>am \<eta>) = add_mset (hd As') (hd AAs') \<cdot>am \<eta>"
    unfolding subst_atm_mset_def by auto
  then have "(map2 add_mset (As' \<cdot>al \<eta>) (AAs' \<cdot>aml \<eta>)) ! 0  = (map2 add_mset (As') (AAs') \<cdot>aml \<eta>) ! 0"
    using Suc by (simp add: Succ(2) subst_atm_mset_def)
  ultimately have "\<forall>i < Suc n. (map2 add_mset (As' \<cdot>al \<eta>) (AAs' \<cdot>aml \<eta>)) ! i =
    (map2 add_mset (As') (AAs') \<cdot>aml \<eta>) ! i"
    using Suc by auto
  then show ?case
    using nn list_eq_iff_nth_eq by metis
qed auto

lemma maximal_wrt_subst: "maximal_wrt (A \<cdot>a \<sigma>) (C \<cdot> \<sigma>) \<Longrightarrow> maximal_wrt A C"
  unfolding maximal_wrt_def using in_atms_of_subst less_atm_stable by blast

lemma strictly_maximal_wrt_subst: "strictly_maximal_wrt (A \<cdot>a \<sigma>) (C \<cdot> \<sigma>) \<Longrightarrow> strictly_maximal_wrt A C"
  unfolding strictly_maximal_wrt_def using in_atms_of_subst less_atm_stable by blast

lemma ground_resolvent_subset:
  assumes
    gr_cas: "is_ground_cls_list CAs" and
    gr_da: "is_ground_cls DA" and
    res_e: "ord_resolve S CAs DA AAs As \<sigma> E"
  shows "E \<subseteq># (\<Union># mset CAs) + DA"
  using res_e
proof (cases rule: ord_resolve.cases)
  case (ord_resolve n Cs D)
  note da = this(1) and e = this(2) and cas_len = this(3) and cs_len = this(4)
    and aas_len = this(5) and as_len = this(6) and cas = this(8) and mgu = this(10)
  then have cs_sub_cas: "\<Union># mset Cs \<subseteq># \<Union># mset CAs"
    using subseteq_list_Union_mset cas_len cs_len by force
  then have cs_sub_cas: "\<Union># mset Cs \<subseteq># \<Union># mset CAs"
    using subseteq_list_Union_mset cas_len cs_len by force
  then have gr_cs: "is_ground_cls_list Cs"
    using gr_cas by simp
  have d_sub_da: "D \<subseteq># DA"
    by (simp add: da)
  then have gr_d: "is_ground_cls D"
    using gr_da is_ground_cls_mono by auto

  have "is_ground_cls (\<Union># mset Cs + D)"
    using gr_cs gr_d by auto
  with e have "E = (\<Union># mset Cs + D)"
    by auto
  then show ?thesis
    using cs_sub_cas d_sub_da by (auto simp: subset_mset.add_mono)
qed

lemma ord_resolve_obtain_clauses:
  assumes
    res_e: "ord_resolve (S_M S M) CAs DA AAs As \<sigma> E" and
    select: "selection S" and
    grounding: "{DA} \<union> set CAs \<subseteq> grounding_of_clss M" and
    n: "length CAs = n" and
    d: "DA = D + negs (mset As)" and
    c: "(\<forall>i < n. CAs ! i = Cs ! i + poss (AAs ! i))" "length Cs = n" "length AAs = n"
  obtains DA'' \<eta>'' CAs'' \<eta>s'' As'' AAs'' D'' Cs'' where
    "length CAs'' = n"
    "length \<eta>s'' = n"
    "DA'' \<in> M"
    "DA'' \<cdot> \<eta>'' = DA"
    "S DA'' \<cdot> \<eta>'' = S_M S M DA"
    "\<forall>CA'' \<in> set CAs''. CA'' \<in> M"
    "CAs'' \<cdot>\<cdot>cl \<eta>s'' = CAs"
    "map S CAs'' \<cdot>\<cdot>cl \<eta>s'' = map (S_M S M) CAs"
    "is_ground_subst \<eta>''"
    "is_ground_subst_list \<eta>s''"
    "As''  \<cdot>al \<eta>'' = As"
    "AAs'' \<cdot>\<cdot>aml \<eta>s'' = AAs"
    "length As'' = n"
    "D'' \<cdot> \<eta>'' = D"
    "DA'' = D'' + (negs (mset As''))"
    "S_M S M (D + negs (mset As)) \<noteq> {#} \<Longrightarrow> negs (mset As'') = S DA''"
    "length Cs'' = n"
    "Cs'' \<cdot>\<cdot>cl \<eta>s'' = Cs"
    "\<forall>i < n. CAs'' ! i = Cs'' ! i + poss (AAs'' ! i)"
    "length AAs'' = n"
  using res_e
proof (cases rule: ord_resolve.cases)
  case (ord_resolve n_twin Cs_twins D_twin)
  note da = this(1) and e = this(2) and cas = this(8) and mgu = this(10) and eligible = this(11)
  from ord_resolve have "n_twin = n" "D_twin = D"
    using n d by auto
  moreover have "Cs_twins = Cs"
    using c cas n calculation(1) \<open>length Cs_twins = n_twin\<close> by (auto simp add: nth_equalityI)
  ultimately
  have nz: "n \<noteq> 0" and cs_len: "length Cs = n" and aas_len: "length AAs = n" and as_len: "length As = n"
    and da: "DA = D + negs (mset As)" and eligible: "eligible (S_M S M) \<sigma> As (D + negs (mset As))"
    and cas: "\<forall>i<n. CAs ! i = Cs ! i + poss (AAs ! i)"
    using ord_resolve by force+

  note n = \<open>n \<noteq> 0\<close> \<open>length CAs = n\<close> \<open>length Cs = n\<close> \<open>length AAs = n\<close> \<open>length As = n\<close>

  interpret S: selection S by (rule select)

  -- \<open>Obtain FO side premises\<close>
  have "\<forall>CA \<in> set CAs. \<exists>CA'' \<eta>c''. CA'' \<in> M \<and> CA'' \<cdot> \<eta>c'' = CA \<and> S CA'' \<cdot> \<eta>c'' = S_M S M CA \<and> is_ground_subst \<eta>c''"
    using grounding S_M_grounding_of_clss select by (metis (no_types) le_supE subset_iff)
  then have "\<forall>i < n. \<exists>CA'' \<eta>c''. CA'' \<in> M \<and> CA'' \<cdot> \<eta>c'' = (CAs ! i) \<and> S CA'' \<cdot> \<eta>c'' = S_M S M (CAs ! i) \<and> is_ground_subst \<eta>c''"
    using n by force
  then obtain \<eta>s''f CAs''f where f_p:
    "\<forall>i < n. CAs''f i \<in> M"
    "\<forall>i < n. (CAs''f i) \<cdot> (\<eta>s''f i) = (CAs ! i)"
    "\<forall>i < n. S (CAs''f i)  \<cdot> (\<eta>s''f i) = S_M S M (CAs ! i)"
    "\<forall>i < n. is_ground_subst (\<eta>s''f i)"
    using n by (metis (no_types))

  define \<eta>s'' where
    "\<eta>s'' = map \<eta>s''f [0 ..<n]"
  define CAs'' where
    "CAs'' = map CAs''f [0 ..<n]"

  have "length \<eta>s'' = n" "length CAs'' = n"
    unfolding \<eta>s''_def CAs''_def by auto
  note n = \<open>length \<eta>s'' = n\<close> \<open>length CAs'' = n\<close> n

  -- \<open>The properties we need of the FO side premises\<close>
  have CAs''_in_M: "\<forall>CA'' \<in> set CAs''. CA'' \<in> M"
    unfolding CAs''_def using f_p(1) by auto
  have CAs''_to_CAs: "CAs'' \<cdot>\<cdot>cl \<eta>s'' = CAs"
    unfolding CAs''_def \<eta>s''_def using f_p(2)  by (auto simp: n intro: nth_equalityI)
  have SCAs''_to_SMCAs: "(map S CAs'') \<cdot>\<cdot>cl \<eta>s'' = map (S_M S M) CAs"
    unfolding CAs''_def \<eta>s''_def using f_p(3) n by (force intro: nth_equalityI)
  have sub_ground: "\<forall>\<eta>c'' \<in> set \<eta>s''. is_ground_subst \<eta>c''"
    unfolding \<eta>s''_def using f_p n by force
  then have "is_ground_subst_list \<eta>s''"
    using n unfolding is_ground_subst_list_def by auto

  -- \<open>Split side premises CAs'' into Cs'' and AAs''\<close>
  obtain AAs'' Cs'' where AAs''_Cs''_p:
   "AAs'' \<cdot>\<cdot>aml \<eta>s'' = AAs" "length Cs'' = n" "Cs'' \<cdot>\<cdot>cl \<eta>s'' = Cs"
   "\<forall>i < n. CAs'' ! i = Cs'' ! i + poss (AAs'' ! i)" "length AAs'' = n"
  proof -
    have "\<forall>i < n. \<exists>AA''. AA'' \<cdot>am \<eta>s'' ! i = AAs ! i \<and> poss AA'' \<subseteq># CAs'' ! i"
    proof (rule, rule)
      fix i
      assume "i < n"
      have "CAs'' ! i \<cdot> \<eta>s'' ! i = CAs ! i"
        using \<open>i < n\<close> \<open>CAs'' \<cdot>\<cdot>cl \<eta>s'' = CAs\<close> n by force
      moreover have "poss (AAs ! i) \<subseteq># CAs !i"
        using \<open>i < n\<close> cas by auto
      ultimately obtain poss_AA'' where
        nn: "poss_AA'' \<cdot> \<eta>s'' ! i = poss (AAs ! i) \<and> poss_AA'' \<subseteq># CAs'' ! i"
        using cas image_mset_of_subset unfolding subst_cls_def by metis
      then have l: "\<forall>L \<in># poss_AA''. is_pos L"
        unfolding subst_cls_def by (metis Melem_subst_cls imageE literal.disc(1)
            literal.map_disc_iff set_image_mset subst_cls_def subst_lit_def)

      define AA'' where
        "AA'' = image_mset atm_of poss_AA''"

      have na: "poss AA'' = poss_AA''"
        using l unfolding AA''_def by auto
      then have "AA'' \<cdot>am \<eta>s'' ! i = AAs ! i"
        using nn by (metis (mono_tags) literal.inject(1) multiset.inj_map_strong subst_cls_poss)
      moreover have "poss AA'' \<subseteq># CAs'' ! i"
        using na nn by auto
      ultimately show "\<exists>AA'. AA' \<cdot>am \<eta>s'' ! i = AAs ! i \<and> poss AA' \<subseteq># CAs'' ! i"
        by blast
    qed
    then obtain AAs''f where 
      AAs''f_p: "\<forall>i < n. AAs''f i \<cdot>am \<eta>s'' ! i = AAs ! i \<and> (poss (AAs''f i)) \<subseteq># CAs'' ! i"
      by metis

    define AAs'' where "AAs'' = map AAs''f [0 ..<n]"

    then have "length AAs'' = n"
      by auto
    note n = n \<open>length AAs'' = n\<close>

    from AAs''_def have "\<forall>i < n. AAs'' ! i \<cdot>am \<eta>s'' ! i = AAs ! i"
      using AAs''f_p by auto
    then have AAs'_AAs: "AAs'' \<cdot>\<cdot>aml \<eta>s'' = AAs"
      using n by (auto intro: nth_equalityI)

    from AAs''_def have AAs''_in_CAs'': "\<forall>i < n. poss (AAs'' ! i) \<subseteq># CAs'' ! i"
      using AAs''f_p by auto

    define Cs'' where
      "Cs'' = map2 (op -) CAs'' (map poss AAs'')"

    have "length Cs'' = n"
      using Cs''_def n by auto
    note n = n \<open>length Cs'' = n\<close>

    have "\<forall>i < n. CAs'' ! i = Cs'' ! i + poss (AAs'' ! i)"
      using AAs''_in_CAs'' Cs''_def n by auto
    then have "Cs'' \<cdot>\<cdot>cl \<eta>s'' = Cs"
      using \<open>CAs'' \<cdot>\<cdot>cl \<eta>s'' = CAs\<close> AAs'_AAs cas n by (auto intro: nth_equalityI)

    show ?thesis
      using that 
        \<open>AAs'' \<cdot>\<cdot>aml \<eta>s'' = AAs\<close> \<open>Cs'' \<cdot>\<cdot>cl \<eta>s'' = Cs\<close> \<open>\<forall>i < n. CAs'' ! i = Cs'' ! i + poss (AAs'' ! i)\<close>
        \<open>length AAs'' = n\<close> \<open>length Cs'' = n\<close>
      by blast
  qed

  -- \<open>Obtain FO main premise\<close>
  have "\<exists>DA'' \<eta>''. DA'' \<in> M \<and> DA = DA'' \<cdot> \<eta>'' \<and> S DA'' \<cdot> \<eta>'' = S_M S M DA \<and> is_ground_subst \<eta>''"
    using grounding S_M_grounding_of_clss select by (metis le_supE singletonI subsetCE)
  then obtain DA'' \<eta>'' where 
    DA''_\<eta>''_p: "DA'' \<in> M \<and> DA = DA'' \<cdot> \<eta>'' \<and> S DA'' \<cdot> \<eta>'' = S_M S M DA \<and> is_ground_subst \<eta>''"
    by auto
  -- \<open>The properties we need of the FO main premise\<close>
  have DA''_in_M: "DA'' \<in> M"
    using DA''_\<eta>''_p by auto
  have DA''_to_DA: "DA'' \<cdot> \<eta>'' = DA"
    using DA''_\<eta>''_p by auto
  have SDA''_to_SMDA: "S DA'' \<cdot> \<eta>'' = S_M S M DA"
    using DA''_\<eta>''_p by auto
  have "is_ground_subst \<eta>''"
    using DA''_\<eta>''_p by auto

  -- \<open>Split main premise DA'' into D'' and As''\<close>
  obtain D'' As'' where D''As''_p:
     "As''  \<cdot>al \<eta>'' = As" "length As'' = n" "D'' \<cdot> \<eta>'' = D" "DA'' = D'' + (negs (mset As''))"
    "S_M S M (D + negs (mset As)) \<noteq> {#} \<Longrightarrow> negs (mset As'') = S DA''"
  proof -
    {
      assume a: "S_M S M (D + negs (mset As)) = {#} \<and> length As = (Suc 0)
        \<and> maximal_wrt (As ! 0 \<cdot>a \<sigma>) ((D + negs (mset As)) \<cdot> \<sigma>)"
      then have as: "mset As = {#As ! 0#}"
        by (auto intro: nth_equalityI)
      then have "negs (mset As) = {#Neg (As ! 0)#}"
        by (simp add: \<open>mset As = {#As ! 0#}\<close>)
      then have "DA = D + {#Neg (As ! 0)#}"
        using da by auto
      then obtain L where "L \<in># DA'' \<and> L \<cdot>l \<eta>'' = Neg (As ! 0)"
        using DA''_to_DA by (metis Melem_subst_cls mset_subset_eq_add_right single_subset_iff)
      then have "Neg (atm_of L) \<in># DA'' \<and> Neg (atm_of L) \<cdot>l \<eta>'' = Neg (As ! 0)"
        by (metis Neg_atm_of_iff literal.sel(2) subst_lit_is_pos)
      then have "[atm_of L] \<cdot>al \<eta>'' = As \<and> negs (mset [atm_of L]) \<subseteq># DA''"
        using as subst_lit_def by auto
      then have "\<exists>As'. As' \<cdot>al \<eta>'' = As \<and> negs (mset As') \<subseteq># DA''
        \<and> (S_M S M (D + negs (mset As)) \<noteq> {#} \<longrightarrow> negs (mset As') = S DA'')"
        using a by blast
    }
    moreover
    {
      assume "S_M S M (D + negs (mset As)) = negs (mset As)"
      then have "negs (mset As) = S DA'' \<cdot> \<eta>''"
        using da \<open>S DA'' \<cdot> \<eta>'' = S_M S M DA\<close> by auto
      then have "\<exists>As'. negs (mset As') = S DA'' \<and> As' \<cdot>al \<eta>'' = As"
        using instance_list[of As "S DA''" \<eta>''] S.S_selects_neg_lits by auto
      then have "\<exists>As'. As' \<cdot>al \<eta>'' = As \<and> negs (mset As') \<subseteq># DA''
        \<and> (S_M S M (D + negs (mset As)) \<noteq> {#} \<longrightarrow> negs (mset As') = S DA'')"
        using S.S_selects_subseteq by auto
    }
    ultimately have "\<exists>As''. As'' \<cdot>al \<eta>'' = As \<and> (negs (mset As'')) \<subseteq># DA''
      \<and> (S_M S M (D + negs (mset As)) \<noteq> {#} \<longrightarrow> negs (mset As'') = S DA'')"
      using eligible unfolding eligible.simps by auto
    then obtain As'' where
      As'_p: "As'' \<cdot>al \<eta>'' = As \<and> negs (mset As'') \<subseteq># DA''
      \<and> (S_M S M (D + negs (mset As)) \<noteq> {#} \<longrightarrow> negs (mset As'') = S DA'')"
      by blast
    then have "length As'' = n"
      using as_len by auto
    note n = n this

    have "As'' \<cdot>al \<eta>'' = As"
      using As'_p by auto

    define D'' where
      "D'' = DA'' - negs (mset As'')"
    then have "DA'' = D'' + negs (mset As'')"
      using As'_p by auto
    then have "D'' \<cdot> \<eta>'' = D"
      using DA''_to_DA da As'_p by auto

    have "S_M S M (D + negs (mset As)) \<noteq> {#} \<Longrightarrow> negs (mset As'') = S DA''"
      using As'_p by blast
    then show ?thesis
      using that \<open>As'' \<cdot>al \<eta>'' = As\<close> \<open>D'' \<cdot> \<eta>''= D\<close> \<open>DA'' = D'' +  (negs (mset As''))\<close> \<open>length As'' = n\<close>
      by metis
  qed

  show ?thesis
    using that[OF n(2,1) DA''_in_M  DA''_to_DA SDA''_to_SMDA CAs''_in_M CAs''_to_CAs SCAs''_to_SMCAs
        \<open>is_ground_subst \<eta>''\<close> \<open>is_ground_subst_list \<eta>s''\<close> \<open>As''  \<cdot>al \<eta>'' = As\<close>
        \<open>AAs'' \<cdot>\<cdot>aml \<eta>s'' = AAs\<close>
        \<open>length As'' = n\<close>
        \<open>D'' \<cdot> \<eta>'' = D\<close>
        \<open>DA'' = D'' + (negs (mset As''))\<close>
        \<open>S_M S M (D + negs (mset As)) \<noteq> {#} \<Longrightarrow> negs (mset As'') = S DA''\<close>
        \<open>length Cs'' = n\<close>
        \<open>Cs'' \<cdot>\<cdot>cl \<eta>s'' = Cs\<close>
        \<open>\<forall>i < n. CAs'' ! i = Cs'' ! i + poss (AAs'' ! i)\<close>
        \<open>length AAs'' = n\<close>]
    by auto
qed

lemma
  assumes "Pos A \<in># C"
  shows "A \<in> atms_of C"
  using assms
  by (simp add: atm_iff_pos_or_neg_lit)

lemma ord_resolve_rename_lifting:
  assumes
    sel_stable: "\<And>\<rho> C. is_renaming \<rho> \<Longrightarrow> S (C \<cdot> \<rho>) = S C \<cdot> \<rho>" and
    res_e: "ord_resolve (S_M S M) CAs DA AAs As \<sigma> E" and
    select: "selection S" and
    grounding: "{DA} \<union> set CAs \<subseteq> grounding_of_clss M"
  obtains \<eta>s \<eta> \<eta>2 CAs'' DA'' AAs'' As'' E'' \<tau> where
    "is_ground_subst \<eta>"
    "is_ground_subst_list \<eta>s"
    "is_ground_subst \<eta>2"
    "ord_resolve_rename S CAs'' DA'' AAs'' As'' \<tau> E''"
    (* In the previous proofs I have CAs and DA on lhs of equality *)
    "CAs'' \<cdot>\<cdot>cl \<eta>s = CAs" "DA'' \<cdot> \<eta> = DA" "E'' \<cdot> \<eta>2 = E" 
    "{DA''} \<union> set CAs'' \<subseteq> M"
  using res_e
proof (cases rule: ord_resolve.cases)
  case (ord_resolve n Cs D)
  note da = this(1) and e = this(2) and cas_len = this(3) and cs_len = this(4) and
    aas_len = this(5) and as_len = this(6) and nz = this(7) and cas = this(8) and
    aas_not_empt = this(9) and mgu = this(10) and eligible = this(11) and str_max = this(12) and
    sel_empt = this(13)

  have sel_ren_list_inv:
    "\<And>\<rho>s Cs. length \<rho>s = length Cs \<Longrightarrow> is_renaming_list \<rho>s \<Longrightarrow> map S (Cs \<cdot>\<cdot>cl \<rho>s) = map S Cs \<cdot>\<cdot>cl \<rho>s"
    using sel_stable unfolding is_renaming_list_def by (auto intro: nth_equalityI)

  note n = \<open>n \<noteq> 0\<close> \<open>length CAs = n\<close> \<open>length Cs = n\<close> \<open>length AAs = n\<close> \<open>length As = n\<close>

  interpret S: selection S by (rule select)

  obtain DA'' \<eta>'' CAs'' \<eta>s'' As'' AAs'' D'' Cs'' where as'':
    "length CAs'' = n"
    "length \<eta>s'' = n"
    "DA'' \<in> M"
    "DA'' \<cdot> \<eta>'' = DA"
    "S DA'' \<cdot> \<eta>'' = S_M S M DA"
    "\<forall>CA'' \<in> set CAs''. CA'' \<in> M"
    "CAs'' \<cdot>\<cdot>cl \<eta>s'' = CAs"
    "map S CAs'' \<cdot>\<cdot>cl \<eta>s'' = map (S_M S M) CAs"
    "is_ground_subst \<eta>''"
    "is_ground_subst_list \<eta>s''"
    "As'' \<cdot>al \<eta>'' = As"
    "AAs'' \<cdot>\<cdot>aml \<eta>s'' = AAs"
    "length As'' = n"
    "D'' \<cdot> \<eta>'' = D"
    "DA'' = D'' + (negs (mset As''))"
    "S_M S M (D + negs (mset As)) \<noteq> {#} \<Longrightarrow> negs (mset As'') = S DA''"
    "length Cs'' = n"
    "Cs'' \<cdot>\<cdot>cl \<eta>s'' = Cs"
    "\<forall>i < n. CAs'' ! i = Cs'' ! i + poss (AAs'' ! i)"
    "length AAs'' = n"
    using ord_resolve_obtain_clauses[of S M CAs DA, OF res_e select grounding n(2) \<open>DA = D + negs (mset As)\<close>
      \<open>\<forall>i<n. CAs ! i = Cs ! i + poss (AAs ! i)\<close> \<open>length Cs = n\<close> \<open>length AAs = n\<close>, of thesis] by blast

  note n = \<open>length CAs'' = n\<close> \<open>length \<eta>s'' = n\<close> \<open>length As'' = n\<close> \<open>length AAs'' = n\<close> \<open>length Cs'' = n\<close> n

  have "length (renamings_apart (DA'' # CAs'')) = Suc n"
    using n renames_apart by auto

  note n = this n

  define \<rho> where
    "\<rho> = hd (renamings_apart (DA'' # CAs''))"
  define \<rho>s where
    "\<rho>s = tl (renamings_apart (DA'' # CAs''))"
  define DA' where
    "DA' = DA'' \<cdot> \<rho>"
  define D' where
    "D' = D'' \<cdot> \<rho>"
  define As' where
    "As' = As'' \<cdot>al \<rho>"
  define CAs' where
    "CAs' = CAs'' \<cdot>\<cdot>cl \<rho>s"
  define Cs' where
    "Cs' = Cs'' \<cdot>\<cdot>cl \<rho>s"
  define AAs' where
    "AAs' = AAs'' \<cdot>\<cdot>aml \<rho>s"
  define \<eta>' where
    "\<eta>' = inv_renaming \<rho> \<odot> \<eta>''"
  define \<eta>s' where
    "\<eta>s' = map inv_renaming \<rho>s \<odot>s \<eta>s''"

  have renames_DA'': "is_renaming \<rho>"
    using renames_apart unfolding \<rho>_def
    by (metis length_greater_0_conv list.exhaust_sel list.set_intros(1) list.simps(3))

  have renames_CAs'': "is_renaming_list \<rho>s"
    using renames_apart unfolding \<rho>s_def
    by (metis is_renaming_list_def length_greater_0_conv list.set_sel(2) list.simps(3))

  have "length \<rho>s = n"
    unfolding \<rho>s_def using n by auto
  note n = n \<open>length \<rho>s = n\<close>
  have "length As' = n"
    unfolding As'_def using n by auto
  have "length CAs' = n"
    using as''(1) n unfolding CAs'_def by auto
  have "length Cs' = n"
    unfolding Cs'_def using n by auto
  have "length AAs' = n"
    unfolding AAs'_def using n by auto
  have "length \<eta>s' = n"
    using as''(2) n unfolding \<eta>s'_def by auto
  note n = \<open>length CAs' = n\<close> \<open>length \<eta>s' = n\<close> \<open>length As' = n\<close> \<open>length AAs' = n\<close> \<open>length Cs' = n\<close> n

  have DA'_DA: "DA' \<cdot> \<eta>' = DA"
    using as''(4) unfolding \<eta>'_def DA'_def using renames_DA'' by simp
  have D'_D: "D' \<cdot> \<eta>' = D"
    using as''(14) unfolding \<eta>'_def D'_def using renames_DA'' by simp
  have As'_As: "As' \<cdot>al \<eta>' = As"
    using as''(11) unfolding \<eta>'_def As'_def using renames_DA'' by auto
  have "S DA' \<cdot> \<eta>' = S_M S M DA"
    using as''(5) unfolding \<eta>'_def DA'_def using renames_DA'' sel_stable by auto
  have CAs'_CAs: "CAs' \<cdot>\<cdot>cl \<eta>s' = CAs"
    using as''(7) unfolding CAs'_def \<eta>s'_def using renames_apart renames_CAs'' n by auto
  have Cs'_Cs: "Cs' \<cdot>\<cdot>cl \<eta>s' = Cs"
    using as''(18) unfolding Cs'_def \<eta>s'_def using renames_apart renames_CAs'' n by auto
  have AAs'_AAs: "AAs' \<cdot>\<cdot>aml \<eta>s' = AAs"
    using as''(12) unfolding \<eta>s'_def AAs'_def using renames_CAs'' using n by auto
  have "map S CAs' \<cdot>\<cdot>cl \<eta>s' = map (S_M S M) CAs"
    unfolding CAs'_def \<eta>s'_def using as''(8) n renames_CAs'' sel_ren_list_inv by auto

  have DA'_split: "DA' = D' + negs (mset As')"
    using as''(15) DA'_def D'_def As'_def by auto
  then have D'_subset_DA': "D' \<subseteq># DA'"
    by auto
  from DA'_split have negs_As'_subset_DA': "negs (mset As') \<subseteq># DA'"
    by auto

  have CAs'_split: "\<forall>i<n. CAs' ! i = Cs' ! i + poss (AAs' ! i)"
    using as''(19) CAs'_def Cs'_def AAs'_def n by auto
  then have "\<forall>i<n. Cs' ! i \<subseteq># CAs' ! i"
    by auto
  from CAs'_split have poss_AAs'_subset_CAs': "\<forall>i<n. poss (AAs' ! i) \<subseteq># CAs' ! i"
    by auto
  then have AAs'_in_atms_of_CAs': "\<forall>i < n. \<forall>A\<in>#AAs' ! i. A \<in> atms_of (CAs' ! i)"
    by (auto simp add: atm_iff_pos_or_neg_lit)

  have as':
    "S_M S M (D + negs (mset As)) \<noteq> {#} \<Longrightarrow> negs (mset As') = S DA'"
  proof -
    assume a: "S_M S M (D + negs (mset As)) \<noteq> {#}"
    then have "negs (mset As'') \<cdot> \<rho> = S DA'' \<cdot> \<rho>"
      using as''(16) unfolding \<rho>_def by metis
    then show "negs (mset As') = S DA'"
      using  As'_def DA'_def using sel_stable[of \<rho> DA''] renames_DA'' by auto
  qed

  have vd: "var_disjoint (DA' # CAs')"
    unfolding DA'_def CAs'_def using renames_apart[of "DA'' # CAs''"]
    unfolding \<rho>_def \<rho>s_def
    by (metis length_greater_0_conv list.exhaust_sel n(6) substitution.subst_cls_lists_Cons
        substitution_axioms zero_less_Suc)

  -- \<open>Introduce ground substitution\<close>
  from vd DA'_DA CAs'_CAs have "\<exists>\<eta>. \<forall>i < Suc n. \<forall>S. S \<subseteq># (DA' # CAs') ! i \<longrightarrow> S \<cdot> (\<eta>'#\<eta>s') ! i = S \<cdot> \<eta>"
    unfolding var_disjoint_def using n by auto
  then obtain \<eta> where \<eta>_p: "\<forall>i < Suc n. \<forall>S. S \<subseteq># (DA' # CAs') ! i \<longrightarrow> S \<cdot> (\<eta>'#\<eta>s') ! i = S \<cdot> \<eta>"
    by auto
  have \<eta>_p_lit: "\<forall>i < Suc n. \<forall>L. L \<in># (DA' # CAs') ! i \<longrightarrow> L \<cdot>l (\<eta>'#\<eta>s') ! i = L \<cdot>l \<eta>"
  proof (rule, rule, rule, rule)
    fix i :: "nat" and L :: "'a literal"
    assume a:
      "i < Suc n"
      "L \<in># (DA' # CAs') ! i"
    then have "\<forall>S. S \<subseteq># (DA' # CAs') ! i \<longrightarrow> S \<cdot> (\<eta>' # \<eta>s') ! i = S \<cdot> \<eta>"
      using \<eta>_p by auto
    then have "{# L #} \<cdot> (\<eta>' # \<eta>s') ! i = {# L #} \<cdot> \<eta>"
      using a by (meson single_subset_iff)
    then show "L \<cdot>l (\<eta>' # \<eta>s') ! i = L \<cdot>l \<eta>" by auto
  qed
  have \<eta>_p_atm: "\<forall>i < Suc n. \<forall>A. A \<in> atms_of ((DA' # CAs') ! i) \<longrightarrow> A \<cdot>a (\<eta>'#\<eta>s') ! i = A \<cdot>a \<eta>"
  proof (rule, rule, rule, rule)
    fix i :: "nat" and A :: "'a"
    assume a:
      "i < Suc n"
      "A \<in> atms_of ((DA' # CAs') ! i)"
    then obtain L where L_p: "atm_of L = A \<and> L \<in># (DA' # CAs') ! i"
      unfolding atms_of_def by auto
    then have "L \<cdot>l (\<eta>'#\<eta>s') ! i = L \<cdot>l \<eta>"
      using \<eta>_p_lit a by auto
    then show "A \<cdot>a (\<eta>' # \<eta>s') ! i = A \<cdot>a \<eta>"
      using L_p unfolding subst_lit_def by (cases L) auto
  qed

  have DA'_DA: "DA' \<cdot> \<eta> = DA"
    using DA'_DA \<eta>_p by auto
  have "D' \<cdot> \<eta> = D" using \<eta>_p D'_D n D'_subset_DA' by auto
  have "As' \<cdot>al \<eta> = As"
  proof (rule nth_equalityI)
    show "length (As' \<cdot>al \<eta>) = length As"
      using n by auto
  next
    show "\<forall>i<length (As' \<cdot>al \<eta>). (As' \<cdot>al \<eta>) ! i = As ! i"
    proof (rule, rule)
      fix i :: "nat"
      assume a: "i < length (As' \<cdot>al \<eta>)"
      have A_eq: "\<forall>A. A \<in> atms_of DA' \<longrightarrow> A \<cdot>a \<eta>' = A \<cdot>a \<eta>"
        using \<eta>_p_atm n by force
      have "As' ! i \<in> atms_of DA'"
        using negs_As'_subset_DA' unfolding atms_of_def
        using a n by force
      then have "As' ! i \<cdot>a \<eta>' = As' ! i \<cdot>a \<eta>"
         using A_eq by simp
      then show "(As' \<cdot>al \<eta>) ! i = As ! i"
        using As'_As \<open>length As' = n\<close> a by auto
    qed
  qed

  have "S DA' \<cdot> \<eta> = S_M S M DA"
    using \<open>S DA' \<cdot> \<eta>' = S_M S M DA\<close> \<eta>_p S.S_selects_subseteq by auto

  from \<eta>_p have \<eta>_p_CAs': "\<forall>i < n. (CAs' ! i) \<cdot> (\<eta>s' ! i) = (CAs'! i) \<cdot> \<eta>"
    using n by auto
  then have "CAs' \<cdot>\<cdot>cl \<eta>s' = CAs' \<cdot>cl \<eta>"
    using n by (auto intro: nth_equalityI)
  then have CAs'_\<eta>_fo_CAs: "CAs' \<cdot>cl \<eta> = CAs"
    using CAs'_CAs \<eta>_p n by auto

  from \<eta>_p have "\<forall>i < n. S (CAs' ! i) \<cdot> \<eta>s' ! i = S (CAs' ! i) \<cdot> \<eta>"
    using S.S_selects_subseteq n by auto
  then have "map S CAs' \<cdot>\<cdot>cl \<eta>s' = map S CAs' \<cdot>cl \<eta>"
    using n by (auto intro: nth_equalityI)
  then have SCAs'_\<eta>_fo_SMCAs: "map S CAs' \<cdot>cl \<eta> = map (S_M S M) CAs"
    using \<open>map S CAs' \<cdot>\<cdot>cl \<eta>s' = map (S_M S M) CAs\<close> by auto

  have "Cs' \<cdot>cl \<eta> = Cs"
  proof (rule nth_equalityI)
    show "length (Cs' \<cdot>cl \<eta>) = length Cs"
      using n by auto
  next
    show "\<forall>i<length (Cs' \<cdot>cl \<eta>). (Cs' \<cdot>cl \<eta>) ! i = Cs ! i"
    proof (rule, rule) (* FIXME: Clean up this mess. *)
      fix i :: "nat"
      assume "i < length (Cs' \<cdot>cl \<eta>)"
      then have a: "i < n"
        using n by force
      have "(Cs' \<cdot>\<cdot>cl \<eta>s') ! i = Cs ! i"
        using Cs'_Cs a n by force
      moreover
      have \<eta>_p_CAs': "\<forall>S. S \<subseteq># CAs' ! i \<longrightarrow> S \<cdot> \<eta>s' ! i = S \<cdot> \<eta>"
        using \<eta>_p a by force
      have "Cs' ! i \<cdot> \<eta>s' ! i = (Cs' \<cdot>cl \<eta>) ! i"
        using \<eta>_p_CAs' \<open>\<forall>i<n. Cs' ! i \<subseteq># CAs' ! i\<close> a n by force
      then have "(Cs' \<cdot>\<cdot>cl \<eta>s') ! i = (Cs' \<cdot>cl \<eta>) ! i "
        using a n by force
      ultimately show "(Cs' \<cdot>cl \<eta>) ! i = Cs ! i"
        by auto
      thm Cs'_Cs \<eta>_p \<open>\<forall>i<n. Cs' ! i \<subseteq># CAs' ! i\<close> a
    qed
  qed

  have AAs'_AAs: "AAs' \<cdot>aml \<eta> = AAs"
  proof (rule nth_equalityI)
    show "length (AAs' \<cdot>aml \<eta>) = length AAs"
      using n by auto
  next
    show "\<forall>i<length (AAs' \<cdot>aml \<eta>). (AAs' \<cdot>aml \<eta>) ! i = AAs ! i"
    proof (rule, rule)
      fix i :: "nat"
      assume a: "i < length (AAs' \<cdot>aml \<eta>)"
      then have "i < n"
        using n by force
      then have "\<forall>A. A \<in> atms_of ((DA' # CAs') ! Suc i) \<longrightarrow> A \<cdot>a (\<eta>' # \<eta>s') ! Suc i = A \<cdot>a \<eta>"
        using \<eta>_p_atm n by force
      then have A_eq: "\<forall>A. A \<in> atms_of (CAs' ! i) \<longrightarrow> A \<cdot>a \<eta>s' ! i = A \<cdot>a \<eta>"
        by auto
      have AAs_CAs': "\<forall>A \<in># AAs' ! i. A \<in> atms_of (CAs' ! i)"
        using AAs'_in_atms_of_CAs' unfolding atms_of_def
        using a n by force
      then have "AAs' ! i \<cdot>am  \<eta>s' ! i = AAs' ! i \<cdot>am \<eta>"
        unfolding subst_atm_mset_def using A_eq unfolding subst_atm_mset_def by auto
      then show "(AAs' \<cdot>aml \<eta>) ! i = AAs ! i"
         using AAs'_AAs \<open>length AAs' = n\<close> \<open>length \<eta>s' = n\<close> a by auto
    qed
  qed

  -- \<open>Obtain MGU and substitution\<close>
  obtain \<tau> \<phi> where \<tau>\<phi>:
    "Some \<tau> = mgu (set_mset ` set (map2 add_mset As' AAs'))"
    "\<tau> \<odot> \<phi> = \<eta> \<odot> \<sigma>"
  proof -
    have uu: "is_unifiers \<sigma> (set_mset ` set (map2 add_mset (As' \<cdot>al \<eta>) (AAs' \<cdot>aml \<eta>)))"
      using mgu mgu_sound is_mgu_def unfolding \<open>AAs' \<cdot>aml \<eta> = AAs\<close> using \<open>As' \<cdot>al \<eta> = As\<close> by auto
    have \<eta>\<sigma>uni: "is_unifiers (\<eta> \<odot> \<sigma>) (set_mset ` set (map2 add_mset As' AAs'))"
    proof -
      have "set_mset ` set (map2 add_mset As' AAs' \<cdot>aml \<eta>) =
        set_mset ` set (map2 add_mset As' AAs') \<cdot>ass \<eta>"
        unfolding subst_atmss_def subst_atm_mset_list_def using subst_atm_mset_def subst_atms_def
        by (simp add: image_image subst_atm_mset_def subst_atms_def)
      then have "is_unifiers \<sigma> (set_mset ` set (map2 add_mset As' AAs') \<cdot>ass \<eta>)"
        using uu by (auto simp: n map2_add_mset_map)
      then show ?thesis
        using is_unifiers_comp by auto
    qed
    then obtain \<tau> where
      \<tau>_p: "Some \<tau> = mgu (set_mset ` set (map2 add_mset As' AAs'))"
      using mgu_complete
      by (metis (mono_tags, hide_lams) List.finite_set finite_imageI finite_set_mset image_iff)
    moreover then obtain \<phi> where \<phi>_p: "\<tau> \<odot> \<phi> = \<eta> \<odot> \<sigma>"
      by (metis (mono_tags, hide_lams) finite_set \<eta>\<sigma>uni finite_imageI finite_set_mset image_iff
          mgu_sound set_mset_mset substitution_ops.is_mgu_def) (* should be simpler *)
    ultimately show thesis
      using that by auto
  qed

  -- \<open>Lifting eligibility\<close>
  have eligible': "eligible S \<tau> As' (D' + negs (mset As'))"
  proof -
    have "S_M S M (D + negs (mset As)) = negs (mset As) \<or> S_M S M (D + negs (mset As)) = {#} \<and>
      length As = 1 \<and> maximal_wrt (As ! 0 \<cdot>a \<sigma>) ((D + negs (mset As)) \<cdot> \<sigma>)"
      using eligible unfolding eligible.simps by auto
    then show ?thesis
    proof
      assume "S_M S M (D + negs (mset As)) = negs (mset As)"
      then have "S_M S M (D + negs (mset As)) \<noteq> {#}"
        using n by force
      then have "S (D' + negs (mset As')) = negs (mset As')"
        using as' DA'_split by auto
      then show ?thesis
        unfolding eligible.simps[simplified]  by auto
    next
      assume asm: "S_M S M (D + negs (mset As)) = {#} \<and> length As = 1 \<and>
        maximal_wrt (As ! 0 \<cdot>a \<sigma>) ((D + negs (mset As)) \<cdot> \<sigma>)"
      then have "S (D' + negs (mset As')) = {#}"
        using \<open>D' \<cdot> \<eta> = D\<close>[symmetric] \<open>As' \<cdot>al \<eta> = As\<close>[symmetric] \<open>S (DA') \<cdot> \<eta> = S_M S M (DA)\<close>
          da DA'_split subst_cls_empty_iff by metis
      moreover from asm have l: "length As' = 1"
        using \<open>As' \<cdot>al \<eta> = As\<close> by auto
      moreover from asm have "maximal_wrt (As' ! 0 \<cdot>a (\<tau> \<odot> \<phi>)) ((D' + negs (mset As')) \<cdot> (\<tau> \<odot> \<phi>))"
        using \<open>As' \<cdot>al \<eta> = As\<close> \<open>D' \<cdot> \<eta> = D\<close> using l \<tau>\<phi> by auto
      then have "maximal_wrt (As' ! 0 \<cdot>a \<tau> \<cdot>a \<phi>) ((D' + negs (mset As')) \<cdot> \<tau> \<cdot> \<phi>)"
        by auto
      then have "maximal_wrt (As' ! 0 \<cdot>a \<tau>) ((D' + negs (mset As')) \<cdot> \<tau>)"
        using maximal_wrt_subst by blast
      ultimately show ?thesis
        unfolding eligible.simps[simplified] by auto
    qed
  qed

  -- \<open>Lifting maximality\<close>
  have maximality: "\<forall>i < n. strictly_maximal_wrt (As' ! i \<cdot>a \<tau>) (Cs' ! i \<cdot> \<tau>)"
    (* Reformulate in list notation? *)
  proof -
    from str_max have "\<forall>i < n. strictly_maximal_wrt ((As' \<cdot>al \<eta>) ! i \<cdot>a \<sigma>) ((Cs' \<cdot>cl \<eta>) ! i \<cdot> \<sigma>)"
      using \<open>As' \<cdot>al \<eta> = As\<close>  \<open>Cs' \<cdot>cl \<eta> = Cs\<close> by simp
    then have "\<forall>i < n. strictly_maximal_wrt (As' ! i \<cdot>a (\<tau> \<odot> \<phi>)) (Cs' ! i \<cdot> (\<tau> \<odot> \<phi>))"
      using n \<tau>\<phi> by simp
    then have "\<forall>i < n. strictly_maximal_wrt (As' ! i \<cdot>a \<tau> \<cdot>a \<phi>) (Cs' ! i \<cdot> \<tau> \<cdot> \<phi>)"
      by auto
    then show "\<forall>i < n. strictly_maximal_wrt (As' ! i \<cdot>a \<tau>) (Cs' ! i \<cdot> \<tau>)"
      using strictly_maximal_wrt_subst \<tau>\<phi> by blast
  qed

  -- \<open>Lifting nothing being selected\<close>
  have nothing_selected: "\<forall>i < n. S (CAs' ! i) = {#}"
  proof -
    have "\<forall>i < n. (map S CAs' \<cdot>cl \<eta>) ! i = map (S_M S M) CAs ! i"
      by (simp add: \<open>map S CAs' \<cdot>cl \<eta> = map (S_M S M) CAs\<close>)
    then have "\<forall>i < n. S (CAs' ! i) \<cdot> \<eta> = S_M S M (CAs ! i)"
      using n by auto
    then have "\<forall>i < n. S (CAs' ! i)  \<cdot> \<eta> = {#}"
      using sel_empt \<open>\<forall>i < n.  S (CAs' ! i) \<cdot> \<eta> = S_M S M (CAs ! i)\<close> by auto
    then show "\<forall>i < n. S (CAs' ! i) = {#}"
      using subst_cls_empty_iff by blast
  qed

  -- \<open>Lifting AAs's non-emptiness\<close>
  have "\<forall>i < n. AAs' ! i \<noteq> {#}"
    using n aas_not_empt \<open>AAs' \<cdot>aml \<eta> = AAs\<close> by auto

  -- \<open>Resolve the lifted clauses\<close>
  define E' where
    "E' = ((\<Union># mset Cs') + D') \<cdot> \<tau>"

  have res_e': "ord_resolve S CAs' DA' AAs' As' \<tau> E'"
    using ord_resolve.intros[of CAs' n Cs' AAs' As' \<tau> S D',
      OF _ _ _ _ _ _ \<open>\<forall>i < n. AAs' ! i \<noteq> {#}\<close> \<tau>\<phi>(1) eligible'
        \<open>\<forall>i < n. strictly_maximal_wrt (As' ! i \<cdot>a \<tau>) (Cs' ! i \<cdot> \<tau>)\<close> \<open>\<forall>i < n. S (CAs' ! i) = {#}\<close>]
    unfolding E'_def using DA'_split n \<open>\<forall>i<n. CAs' ! i = Cs' ! i + poss (AAs' ! i)\<close> by blast

  -- \<open>Prove resolvent instantiates to ground resolvent\<close>
  have e'\<phi>e: "E' \<cdot> \<phi> = E"
  proof -
    have "E' \<cdot> \<phi> = ((\<Union># mset Cs') + D') \<cdot> (\<tau> \<odot> \<phi>)"
      unfolding E'_def by auto
    also have "\<dots> = (\<Union># mset Cs' + D') \<cdot> (\<eta> \<odot> \<sigma>)"
      using \<tau>\<phi> by auto
    also have "\<dots> = (\<Union># mset Cs + D) \<cdot> \<sigma>"
      using \<open>Cs' \<cdot>cl \<eta> = Cs\<close> \<open>D' \<cdot> \<eta> = D\<close> by auto
    also have "\<dots> = E"
      using e by auto
    finally show e'\<phi>e: "E' \<cdot> \<phi> = E"
      .
  qed

  -- \<open>Replace @{term \<phi>} with a true ground substitution\<close>
  obtain \<eta>2 where
    ground_\<eta>2: "is_ground_subst \<eta>2" "E' \<cdot> \<eta>2 = E"
  proof -
    have "is_ground_cls_list CAs" "is_ground_cls DA"
      using grounding grounding_ground unfolding is_ground_cls_list_def by auto
    then have "is_ground_cls E"
      using res_e ground_resolvent_subset by (force intro: is_ground_cls_mono)
    then show thesis
      using that e'\<phi>e make_ground_subst by auto
  qed


  -- \<open>Wrap up the proof\<close>
  have "ord_resolve S (CAs'' \<cdot>\<cdot>cl \<rho>s) (DA'' \<cdot> \<rho>) (AAs'' \<cdot>\<cdot>aml \<rho>s) (As'' \<cdot>al \<rho>) \<tau> E'"
    using res_e' As'_def \<rho>_def AAs'_def \<rho>s_def DA'_def \<rho>_def CAs'_def \<rho>s_def by simp
  moreover have "\<forall>i<n. poss (AAs'' ! i) \<subseteq># CAs'' ! i"
    using as''(19) by auto
  moreover have "negs (mset As'') \<subseteq># DA''"
    using local.as''(15) by auto
  ultimately have "ord_resolve_rename S CAs'' DA'' AAs'' As'' \<tau> E'"
    using ord_resolve_rename[of CAs'' n AAs'' As'' DA'' \<rho> \<rho>s S \<tau> E'] \<rho>_def \<rho>s_def n by auto
  then show thesis
    using that[of \<eta>'' \<eta>s'' \<eta>2 CAs'' DA''] \<open>is_ground_subst \<eta>''\<close> \<open>is_ground_subst_list \<eta>s''\<close>
      \<open>is_ground_subst \<eta>2\<close> \<open>CAs'' \<cdot>\<cdot>cl \<eta>s'' = CAs\<close> \<open>DA'' \<cdot> \<eta>'' = DA\<close> \<open>E' \<cdot> \<eta>2 = E\<close> \<open>DA'' \<in> M\<close>
      \<open>\<forall>CA \<in> set CAs''. CA \<in> M\<close> by blast
qed

end

end
