(*******************************************************************************

  Project: Development of Security Protocols by Refinement

  Module:  Auth_simple/m2_auth_chan.thy (Isabelle/HOL 2016-1)
  ID:      $Id: m2_auth_chan.thy 133854 2017-03-20 17:53:50Z csprenge $
  Author:  Christoph Sprenger, ETH Zurich <sprenger@inf.ethz.ch>
  
  One-Way authentication protocols
  Refinement 2: protocol using authentic channels

  Copyright (c) 2009-2016 Christoph Sprenger 
  Licence: LGPL

*******************************************************************************)

section {* Refinement 2a: Authentic Channel Protocol *}

theory m2_auth_chan imports m1_auth "../Refinement/Channels"
begin

text {* We refine the abstract authentication protocol to a version of the 
ISO/IEC 9798-3 protocol using abstract channels. In standard protocol notation, 
the original protocol is specified as follows.
\[
\begin{array}{llll}
  \mathrm{M1.} & A \rightarrow B & : & A, B, N_A \\
  \mathrm{M2.} & B \rightarrow A & : & \{N_B, N_A, A\}_{K^{-1}(B)} 
\end{array}
\]
We introduce insecure channels between pairs of agents for the first message and 
authentic channels for the second. *}

declare domIff [simp, iff del]


(******************************************************************************)
subsection {* State *}
(******************************************************************************)

text {* State: we extend the state with insecure and authentic channels 
defined above. *}

record m2_state = m1_state +
  chan :: "chmsg set"


text {* Observations. *}

type_synonym 
  m2_obs = m1_state 

definition 
  m2_obs :: "m2_state \<Rightarrow> m2_obs" where
  "m2_obs s \<equiv> \<lparr> 
     runs = runs s
  \<rparr>"


(******************************************************************************)
subsection {* Events *}
(******************************************************************************)

definition
  m2_step1 :: "[rid_t, agent, agent, nonce] \<Rightarrow> (m2_state \<times> m2_state) set" 
where
  "m2_step1 Ra A B Na \<equiv> {(s, s1).
     (* guards *)
     Ra \<notin> dom (runs s) \<and>
     Na = Ra$0 \<and>

     (* actions *)
     s1 = s\<lparr>
       runs := (runs s)(Ra \<mapsto> (Init, [A, B], [])), 
       chan := insert (Insec A B (Msg [aNon Na])) (chan s)  
     \<rparr>
  }"

definition
  m2_step2 :: "[rid_t, agent, agent, nonce, nonce] \<Rightarrow> (m2_state \<times> m2_state) set"
where
  "m2_step2 Rb A B Na Nb \<equiv> {(s, s1).
     (* guards *)
     Rb \<notin> dom (runs s) \<and>
     Nb = Rb$0 \<and>

     Insec A B (Msg [aNon Na]) \<in> chan s \<and>                          (* rcv M1 *)

     (* actions *)
     s1 = s\<lparr> 
       runs := (runs s)(Rb \<mapsto> (Resp, [A, B], [aNon Na])), 
       chan := insert (Auth B A (Msg [aNon Nb, aNon Na])) (chan s)  (* snd M2 *) 
     \<rparr>  
  }"

definition
  m2_step3 :: "[rid_t, agent, agent, nonce, nonce] \<Rightarrow> (m2_state \<times> m2_state) set"
where
  "m2_step3 Ra A B Na Nb \<equiv> {(s, s1).
     (* guards *)
     runs s Ra = Some (Init, [A, B], []) \<and>
     Na = Ra$0 \<and>

     Auth B A (Msg [aNon Nb, aNon Na]) \<in> chan s \<and>            (* recv M2 *)

     (* actions *)
     s1 = s\<lparr> 
       runs := (runs s)(Ra \<mapsto> (Init, [A, B], [aNon Nb]))
     \<rparr>  
  }"


text {* Intruder fake event. *}

definition     -- {* refines @{term Id} *} 
  m2_fake :: "(m2_state \<times> m2_state) set"
where
  "m2_fake \<equiv> {(s, s1). 

    (* actions: *)
    s1 = s\<lparr> chan := fake ik0 (dom (runs s)) (chan s) \<rparr>
  }"


text {* Transition system. *}

definition 
  m2_init :: "m2_state set" 
where 
  "m2_init \<equiv> { \<lparr> 
     runs = empty, 
     chan = {}
  \<rparr> }"

definition 
  m2_trans :: "(m2_state \<times> m2_state) set" where
  "m2_trans \<equiv> (\<Union>A B Ra Rb Na Nb. 
     (m2_step1 Ra A B Na)    \<union>
     (m2_step2 Rb A B Na Nb) \<union>
     (m2_step3 Ra A B Na Nb) \<union>
     m2_fake \<union>
     Id
  )"

definition
  m2 :: "(m2_state, m2_obs) spec" where
  "m2 \<equiv> \<lparr>
    init = m2_init,
    trans = m2_trans, 
    obs = m2_obs
  \<rparr>"

lemmas m2_defs = 
  m2_def m2_init_def m2_trans_def m2_obs_def
  m2_step1_def m2_step2_def m2_step3_def m2_fake_def 


(******************************************************************************)
subsection {* Invariants *}
(******************************************************************************)

subsubsection {* Authentic channel and responder *}
(******************************************************************************)

text {* This property relates the messages in the authentic channel to the 
responder run frame. *}

definition 
  m2_inv1_auth :: "m2_state set" where
  "m2_inv1_auth \<equiv> {s. \<forall>A B Na Nb. 
     Auth B A (Msg [aNon Nb, aNon Na]) \<in> chan s \<longrightarrow> B \<notin> bad \<longrightarrow> A \<notin> bad \<longrightarrow> 
       (\<exists>Rb. runs s Rb = Some (Resp, [A, B], [aNon Na]) \<and> Nb = Rb$0)
  }"

lemmas m2_inv1_authI = 
  m2_inv1_auth_def [THEN setc_def_to_intro, rule_format]
lemmas m2_inv1_authE [elim] = 
  m2_inv1_auth_def [THEN setc_def_to_elim, rule_format]
lemmas m2_inv1_authD [dest] = 
  m2_inv1_auth_def [THEN setc_def_to_dest, rule_format, rotated 1]


text {* Invariance proof. *}

lemma PO_m2_inv2_init [iff]:
  "init m2 \<subseteq> m2_inv1_auth"
by (auto simp add: PO_hoare_def m2_defs intro!: m2_inv1_authI) 

lemma PO_m2_inv2_trans [iff]:
  "{m2_inv1_auth} trans m2 {> m2_inv1_auth}"
apply (auto simp add: PO_hoare_def m2_defs intro!: m2_inv1_authI) 
apply (auto dest: dom_lemmas)
-- {* 1 subgoal *}
apply (force)                            (* SLOW *)
done

lemma PO_m2_inv2 [iff]: "reach m2 \<subseteq> m2_inv1_auth"
by (rule_tac inv_rule_incr) (auto)


(******************************************************************************)
subsection {* Refinement *}
(******************************************************************************)

text {* Simulation relation and mediator function. This is a pure superposition 
refinement. *}

definition
  R12 :: "(m1_state \<times> m2_state) set" where
  "R12 \<equiv> {(s, t). runs s = runs t}"           -- {* That's it! *}
 
definition 
  med21 :: "m2_obs \<Rightarrow> m1_obs" where
  "med21 \<equiv> id" 


text {* Refinement proof *}

lemma PO_m2_step1_refines_m1_step1:
  "{R12} 
     (m1_step1 Ra A B Na), (m2_step1 Ra A B Na) 
   {> R12}"
by (auto simp add: PO_rhoare_defs R12_def m1_defs m2_defs)

lemma PO_m2_step2_refines_m1_step2:
  "{R12} 
     (m1_step2 Ra A B Na Nb), (m2_step2 Ra A B Na Nb) 
   {> R12}"
by (auto simp add: PO_rhoare_defs R12_def m1_defs m2_defs)

lemma PO_m2_step3_refines_m1_step3:
  "{R12 \<inter> UNIV \<times> m2_inv1_auth} 
     (m1_step3 Ra A B Na Nb), (m2_step3 Ra A B Na Nb) 
   {> R12}"
by (auto simp add: PO_rhoare_defs R12_def m1_defs m2_defs)


text {* New fake event refines skip. *}

lemma PO_m2_fake_refines_m1_skip:
  "{R12} Id, m2_fake {> R12}"
by (auto simp add: PO_rhoare_defs R12_def m1_defs m2_defs)

lemmas PO_m2_trans_refines_m1_trans = 
  PO_m2_step1_refines_m1_step1 PO_m2_step2_refines_m1_step2
  PO_m2_step3_refines_m1_step3 PO_m2_fake_refines_m1_skip 


text {* All together now... *}

lemma PO_m2_refines_init_m1 [iff]:
  "init m2 \<subseteq> R12``(init m1)"
by (auto simp add: R12_def m1_defs m2_defs)

lemma PO_m2_refines_trans_m1 [iff]:
  "{R12 \<inter> UNIV \<times> m2_inv1_auth} 
     (trans m1), (trans m2) 
   {> R12}"
apply (auto simp add: m2_def m2_trans_def m1_def m1_trans_def)
apply (blast intro!: PO_m2_trans_refines_m1_trans)+
done

lemma PO_obs_consistent [iff]:
  "obs_consistent R12 med21 m1 m2"
by (auto simp add: obs_consistent_def R12_def med21_def m1_defs m2_defs)

lemma m2_refines_m1:
  "refines 
     (R12 \<inter> UNIV \<times> m2_inv1_auth)
     med21 m1 m2"
by (rule Refinement_using_invariants) (auto)


end
