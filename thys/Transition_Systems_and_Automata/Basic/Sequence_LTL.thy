section {* Linear Temporal Logic on Streams *}

theory Sequence_LTL
imports
  "Sequence"
  "HOL-Library.Linear_Temporal_Logic_on_Streams"
begin

  subsection {* Basics *}

  (* these destroy the holds constant too eagerly *)
  lemmas [simp del] = holds.simps holds_eq1 holds_eq2 not_holds_eq

  lemma holds_smap[iff]: "holds P (smap f w) \<longleftrightarrow> holds (P \<circ> f) w" unfolding holds.simps by simp

  lemmas [iff] = ev_sconst alw_sconst ev_smap alw_smap hld_smap'

  lemmas [iff] = alw_ev_stl
  lemma alw_ev_sdrop[iff]: "alw (ev P) (sdrop n w) \<longleftrightarrow> alw (ev P) w"
    using alw_ev_sdrop alw_sdrop by blast
  lemma alw_ev_scons[iff]: "alw (ev P) (a ## w) \<longleftrightarrow> alw (ev P) w" by (metis alw_ev_stl stream.sel(2))
  lemma alw_ev_shift[iff]: "alw (ev P) (u @- v) \<longleftrightarrow> alw (ev P) v" by (induct u) (auto)

  lemmas [simp del, iff] = ev_alw_stl
  lemma ev_alw_sdrop[iff]: "ev (alw P) (sdrop n w) \<longleftrightarrow> ev (alw P) w"
    using alwD alw_alw alw_sdrop ev_alw_imp_alw_ev not_ev_iff by metis
  lemma ev_alw_scons[iff]: "ev (alw P) (a ## w) \<longleftrightarrow> ev (alw P) w" by (metis ev_alw_stl stream.sel(2))
  lemma ev_alw_shift[iff]: "ev (alw P) (u @- v) \<longleftrightarrow> ev (alw P) v" by (induct u) (auto)

  lemma holds_sconst[iff]: "holds P (sconst a) \<longleftrightarrow> P a" unfolding holds.simps by simp
  lemma HLD_sconst[iff]: "HLD A (sconst a) \<longleftrightarrow> a \<in> A" unfolding HLD_def holds.simps by simp

  lemma ev_alt_def: "ev \<phi> w \<longleftrightarrow> (\<exists> u v. w = u @- v \<and> \<phi> v)"
    using ev.base ev_shift ev_imp_shift by metis
  lemma ev_stl_alt_def: "ev \<phi> (stl w) \<longleftrightarrow> (\<exists> u v. w = u @- v \<and> u \<noteq> [] \<and> \<phi> v)"
    unfolding ev_alt_def by (cases w) (force simp: scons_eq)

  lemma ev_HLD_sset: "ev (HLD A) w \<longleftrightarrow> sset w \<inter> A \<noteq> {}" unfolding HLD_def ev_holds_sset by auto

  lemma alw_ev_coinduct[case_names alw_ev, consumes 1]:
    assumes "R w"
    assumes "\<And> w. R w \<Longrightarrow> ev \<phi> w \<and> ev R (stl w)"
    shows "alw (ev \<phi>) w"
  proof -
    have "ev R w" using assms(1) by rule
    then show ?thesis using assms(2) by (coinduct) (metis alw_sdrop not_ev_iff sdrop_stl sdrop_wait)
  qed

  subsection {* Acceptance Conditions *}

  abbreviation "infs P w \<equiv> alw (ev (holds P)) w"

  lemma infs_suffix: "infs P w \<longleftrightarrow> (\<forall> u v. w = u @- v \<longrightarrow> Bex (sset v) P)"
    using alwD alw_iff_sdrop alw_shift ev_holds_sset stake_sdrop by (metis (mono_tags, hide_lams))
  lemma infs_snth: "infs P w \<longleftrightarrow> (\<forall> n. \<exists> k \<ge> n. P (w !! k))"
    by (auto simp: alw_iff_sdrop ev_iff_sdrop holds.simps intro: le_add1 dest: le_Suc_ex)
  lemma infs_infm: "infs P w \<longleftrightarrow> (\<exists>\<^sub>\<infinity> i. P (w !! i))"
    unfolding infs_snth INFM_nat_le by rule

  lemma infs_coinduct[case_names infs, coinduct pred: infs]:
    assumes "R w"
    assumes "\<And> w. R w \<Longrightarrow> \<exists> u v. w = u @- v \<and> Bex (set u) P \<and> R v"
    shows "infs P w"
    using assms by (coinduct rule: alw_ev_coinduct) (force simp: ev_holds_sset ev_stl_alt_def)
  lemma infs_flat_coinduct[case_names infs_flat, consumes 1]:
    assumes "R w"
    assumes "\<And> u v. R (u ## v) \<Longrightarrow> Bex (set u) P \<and> R v"
    shows "infs P (flat w)"
    using assms by (coinduction arbitrary: w) (metis empty_iff flat_Stream list.set(1) stream.exhaust)

  lemma infs_mono: "(\<And> a. a \<in> sset w \<Longrightarrow> P a \<Longrightarrow> Q a) \<Longrightarrow> infs P w \<Longrightarrow> infs Q w"
    unfolding infs_snth by force

  lemma infs_all: "Ball (sset w) P \<Longrightarrow> infs P w" unfolding infs_snth by auto
  lemma infs_any: "infs P w \<Longrightarrow> Bex (sset w) P" unfolding ev_holds_sset by auto

  lemma infs_cycle[iff]:
    assumes "w \<noteq> []"
    shows "infs P (cycle w) \<longleftrightarrow> Bex (set w) P"
  proof
    show "infs P (cycle w) \<Longrightarrow> Bex (set w) P"
      using assms by (auto simp: ev_holds_sset dest: alwD)
    show "Bex (set w) P \<Longrightarrow> infs P (cycle w)"
      using assms by (coinduction rule: infs_coinduct) (blast dest: cycle_decomp)
  qed

end