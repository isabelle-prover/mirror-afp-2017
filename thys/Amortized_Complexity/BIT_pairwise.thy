theory BIT_pairwise
imports List_Factoring BIT
begin
  




lemma L_sublist: "S \<subseteq> {..<length init}
  \<Longrightarrow> map_pmf (\<lambda>l. sublist l S) (Prob_Theory.L (length init))
      = (Prob_Theory.L (length (sublist init S)))"
proof(induct init arbitrary: S)
  case (Cons a as)
  then have passt: "{j. Suc j \<in> S} \<subseteq> {..<length as}" by auto

  have " map_pmf (\<lambda>l. sublist l S) (Prob_Theory.L (length (a # as))) = 
    Prob_Theory.L (length as) \<bind>
    (\<lambda>x. bernoulli_pmf (1 / 2) \<bind>
          (\<lambda>xa. return_pmf
                  ((if 0 \<in> S then [xa] else []) @ sublist x {j. Suc j \<in> S})))"
      by(simp add: map_pmf_def bind_return_pmf bind_assoc_pmf sublist_Cons) 
  also have "\<dots> = (bernoulli_pmf (1 / 2)) \<bind> 
          (\<lambda>xa. (Prob_Theory.L (length as) \<bind>
    (\<lambda>x. return_pmf ((if 0 \<in> S then [xa] else []) @ sublist x {j. Suc j \<in> S}))))"
        by(rule bind_commute_pmf)
   also have "\<dots> = (bernoulli_pmf (1 / 2)) \<bind> 
          (\<lambda>xa. (map_pmf (\<lambda>x. (sublist x {j. Suc j \<in> S})) (Prob_Theory.L (length as)))
              \<bind>  (\<lambda>xs. return_pmf ((if 0 \<in> S then [xa] else []) @ xs)))"
      by(simp add: bind_return_pmf bind_assoc_pmf map_pmf_def)
   also have "\<dots> = (bernoulli_pmf (1 / 2)) \<bind> 
          (\<lambda>xa. Prob_Theory.L (length (sublist as {j. Suc j \<in> S}))
              \<bind>  (\<lambda>xs. return_pmf ((if 0 \<in> S then [xa] else []) @ xs)))"
        using Cons(1)[OF passt] by auto
   also have "\<dots> = Prob_Theory.L (length (sublist (a # as) S))"
      apply(auto simp add: sublist_Cons bind_return_pmf')
      by(rule bind_commute_pmf)
   finally show ?case .
qed (simp)

lemma L_sublist_Lxy: "x\<in>set init \<Longrightarrow> y\<in>set init \<Longrightarrow> x\<noteq>y \<Longrightarrow> distinct init 
  \<Longrightarrow> map_pmf (\<lambda>l. sublist l {index init x,index init y}) (Prob_Theory.L (length init))
      = (Prob_Theory.L (length (Lxy init {x,y})))"
proof -
  case goal1
  from goal1(4) have setinit: "(index init) ` set init = {0..<length init}" 
  proof(induct init)
    case (Cons a as)
    with Cons have iH: "index as ` set as = {0..<length as}" by auto
    from Cons have 1:"(set as \<inter> {x. (a \<noteq> x)}) = set as" by fastforce
    have 2: "(\<lambda>a. Suc (index as a)) ` set as =
            (\<lambda>a. Suc a) ` ((index as) ` set as )" by auto
    show ?case
    apply(simp add: 1 2 iH) by auto
  qed simp

  have xy_le: "index init x<length init" "index init y<length init" using goal1 by auto
  have "map_pmf (\<lambda>l. sublist l {index init x,index init y}) (Prob_Theory.L (length init))
      = (Prob_Theory.L (length (sublist init {index init x,index init y})))"
        apply(rule L_sublist)
        using goal1(1,2) by auto
  moreover have "length (Lxy init {x,y}) = length (sublist init {index init x,index init y})"
  proof -
    have "set (Lxy init {x,y}) = {x,y}" 
      using goal1(1,2) by(simp add: Lxy_set_filter)
    moreover have "card {x,y} = 2" using goal1(3) by auto
    moreover have "distinct (Lxy init {x,y})" using goal1(4) by(simp add: Lxy_distinct)
    ultimately have 1: "length (Lxy init {x,y}) = 2" by(simp add: distinct_card[symmetric])
    have "set (sublist init {index init x,index init y}) = {(init ! i) | i.  i < length init \<and> i \<in> {index init x,index init y}}" 
      using goal1(1,2) by(simp add: set_sublist)
    moreover have "card {(init ! i) | i.  i < length init \<and> i \<in> {index init x,index init y}} = 2"
    proof -
      have 1: "{(init ! i) | i.  i < length init \<and> i \<in> {index init x,index init y}} = {init ! index init x, init ! index init y}" using xy_le by blast
      also have "\<dots> = {x,y}" using nth_index goal1(1,2) by auto 
      finally show ?thesis using goal1(3) by auto
    qed
    moreover have "distinct (sublist init {index init x,index init y})" using goal1(4) by(simp)
    ultimately have 2: "length (sublist init {index init x,index init y}) = 2" by(simp add: distinct_card[symmetric])
    show ?thesis using 1 2 by simp
  qed
  ultimately show ?case by simp
qed
  
lemma sublist_map: "map f (sublist xs S) = sublist (map f xs) S"
apply(induct xs arbitrary: S) by(simp_all  add: sublist_Cons)

lemma sublist_empty: "(\<forall>i\<in>S. i\<ge>length xs) \<Longrightarrow> sublist xs S = []"
proof -
  assume "(\<forall>i\<in>S. i\<ge>length xs)"
  then have "set (sublist xs S) = {}" apply(simp add: set_sublist) by force
  then show "sublist xs S = []" by simp
qed


lemma sublist_project': "i < length xs \<Longrightarrow> j < length xs \<Longrightarrow> i<j
   \<Longrightarrow> sublist xs {i,j} = [xs!i, xs!j]"
proof -
  assume il: "i < length xs" and jl: "j < length xs" and ij: "i<j"

  from il obtain a as where dec1: "a @ [xs!i] @ as = xs" 
           and "a = take i xs" "as=drop (Suc i) xs" 
           and length_a: "length a = i" and length_as: "length as = length xs - i - 1"using id_take_nth_drop by fastforce
  have "j\<ge>length (a @ [xs!i])" using length_a ij by auto
  then have "((a @ [xs!i]) @ as) ! j = as ! (j-length (a @ [xs ! i]))" using nth_append[where xs="a @ [xs!i]" and ys="as"]
    by(simp)
  then have xsj: "xs ! j = as ! (j-i-1)" using dec1 length_a by auto   
  have las: "(j-i-1) < length as" using length_as jl ij by simp
  obtain b c where dec2: "b @ [xs!j] @ c = as"
            and "b = take (j-i-1) as" "c=drop (Suc (j-i-1)) as"
            and length_b: "length b = j-i-1" using id_take_nth_drop[OF las] xsj by force
  have xs_dec: "a @ [xs!i] @ b @ [xs!j] @ c = xs" using dec1 dec2 by auto 
         
  have s2: "{k. (k + i \<in> {i, j})} = {0,j-i}"  using ij by force
  have s3: "{k. (k  + length [xs ! i] \<in> {0, j-i})} = {j-i-1}"  using ij by force
  have s4: "{k. (k  + length b \<in> {j-i-1})} = {0}"  using length_b by force
  have s5: "{k. (k  + length [xs!j] \<in> {0})} = {}" by force
  have l1: "sublist a {i,j} = []"
    apply(rule sublist_empty) using length_a ij by fastforce
  have l2: "sublist b {j - Suc i} = []"
    apply(rule sublist_empty) using length_b ij by fastforce
  have "sublist ( a @ [xs!i] @ b @ [xs!j] @ c) {i,j} = [xs!i, xs!j]"
      apply(simp only: sublist_append length_a s2 s3 s4 s5)
      by(simp add: l1 l2)
  then show "sublist xs {i,j} = [xs!i, xs!j]" unfolding xs_dec .
qed

lemma sublist_project: "i < length xs \<Longrightarrow> j < length xs \<Longrightarrow> i<j
   \<Longrightarrow> sublist xs {i,j} ! 0 = xs ! i \<and> sublist xs {i,j} ! 1 = xs ! j"
proof -
  case goal1
  then have "sublist xs {i,j} = [xs!i, xs!j]" by(rule sublist_project')
  then show ?thesis by simp
qed


lemma BIT_pairwise': " qs \<in> {xs. set xs \<subseteq> set init} \<Longrightarrow>
       (x, y) \<in> {(x, y) |x y. x \<in> set init \<and> y \<in> set init \<and> x \<noteq> y} \<Longrightarrow>
       x \<noteq> y \<Longrightarrow> n < Lastxy qs {x, y} \<Longrightarrow> Pbefore_in x y BIT qs init n = Pbefore_in x y BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x, y} qs n)"
proof -
  case goal1 
  then have xyininit: "{x, y} \<subseteq> set init" 
        and qsininit: "set qs \<subseteq> set init" by auto
  have dinit: "distinct init" sorry
  from goal1 have xny: "x\<noteq>y" by simp

  have xyininit': "{y,x} \<subseteq> set init" using xyininit by auto
 
    have a: "x \<in> set init" "y\<in>set init" using goal1 by auto 

    { fix n
    have strong: "n< Lastxy qs {x, y} \<Longrightarrow> 
      map_pmf (\<lambda>(l,(w,i)). (Lxy l {x,y},(sublist w {index init x,index init y},Lxy init {x,y}))) (config'' BIT qs init n) =
      config'' BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x,y} qs n)"

    proof (induct n)
      case 0
      have indexinprojectedlist: "(nrofnextxy {x,y} qs 0) = 0" using nrofnextxy0 by auto


      have " map_pmf (\<lambda>(l,(w,i)). (Lxy l {x,y},(sublist w {index init x,index init y},Lxy init {x,y}))) (config'' BIT qs init 0)
          =  map_pmf (\<lambda>w. (Lxy init {x,y}, (w, Lxy init {x,y}))) (map_pmf (\<lambda>l. sublist l {index init x,index init y}) (Prob_Theory.L (length init)))"
              by(simp add: bind_return_pmf map_pmf_def bind_assoc_pmf split_def BIT_init_def)
      also have "\<dots> = map_pmf (\<lambda>w. (Lxy init {x,y}, (w, Lxy init {x,y}))) (Prob_Theory.L (length (Lxy init {x, y})))" 
          using L_sublist_Lxy[OF a xny dinit] by simp
      also have "\<dots> = config'' BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x, y} qs 0)"
          unfolding indexinprojectedlist by(simp add: BIT_init_def bind_return_pmf bind_assoc_pmf map_pmf_def)
      finally show ?case . 
    next
      case (Suc n)
      then have nLastxy: "n <  Lastxy qs {x, y}" by auto
      also have "\<dots> \<le> length qs" by (rule Lastxy_length)
      finally have nqs: "n<length qs" .
      thm Suc(1)[OF nLastxy]
      from nqs have qininit: "qs!n \<in>  set init" using qsininit by auto

      from  Suc(1)[OF nLastxy] have iH: "map_pmf
   (\<lambda>(l, w, i) .
          (Lxy l {x, y},
           sublist w {index init x, index init y},
           Lxy init {x, y}))
   (Partial_Cost_Model.config'_rand BIT
     (BIT_init init \<bind> (\<lambda>is. return_pmf (init, is)))
     (take n qs)) =
  Partial_Cost_Model.config'_rand BIT
   (fst BIT (Lxy init {x, y}) \<bind>
    (\<lambda>is. return_pmf (Lxy init {x, y}, is)))
   (take (nrofnextxy {x, y} qs n) (Lxy qs {x, y}))" by (simp add: split_def)

      show ?case 
      proof (cases "qs!n \<in> {x,y}")
        case True
        note whatisq=this

        have 5: "(nrofnextxy {x, y} qs n) < length (Lxy qs {x,y})" sorry
        have 4: "(Lxy qs {x, y} ! nrofnextxy {x, y} qs n)  = qs ! n" using nqs sorry

        thm nrofnextxy_Suc[OF nqs True]  
        have "map_pmf (\<lambda>(l,(w,i)). (Lxy l {x,y}, (sublist w {index init x,index init y},Lxy init {x,y}))) (config'' BIT qs init (Suc n)) =
         map_pmf (\<lambda>(l,(w,i)). (Lxy l {x,y},(sublist w {index init x,index init y},Lxy init {x,y}))) (config'' BIT qs init n \<bind>
              (\<lambda>s. BIT_step s (qs ! n) \<bind> (\<lambda>(a, nis). return_pmf (step (fst s) (qs ! n) a, nis))))"
            using nqs by(simp add: BIT_init_def take_Suc_conv_app_nth bind_return_pmf bind_assoc_pmf config'_rand_snoc) 
        also have "\<dots> =
        map_pmf (\<lambda>(l,(w,i)). (Lxy l {x,y}, (sublist w {index init x,index init y},Lxy init {x,y}))) (config'' BIT qs init n) \<bind>
        (\<lambda>s.
            BIT_step s (Lxy qs {x, y} ! nrofnextxy {x, y} qs n) \<bind>
            (\<lambda>(a, nis). return_pmf (step (fst s) (Lxy qs {x, y} ! nrofnextxy {x, y} qs n) a, nis))) "
           apply(simp add: map_pmf_def split_def bind_return_pmf bind_assoc_pmf)
           apply(simp add: 4 BIT_step_def bind_return_pmf)
        proof (rule bind_pmf_cong)
          case (goal2 z)
          let ?s = "fst z"
          let ?b = "fst (snd z)"

          from goal2 have z: "set (?s) = set init" using config_rand_set[of BIT, simplified]  by metis
          with True have qLxy: "qs ! n \<in> set (Lxy (?s) {x, y})" using   xyininit by (simp add: Lxy_set_filter)
          from goal2 have dz: "distinct (?s)" using dinit config_rand_distinct[of BIT, simplified] by metis
          then have dLxy: "distinct (Lxy (?s) {x, y})" using Lxy_distinct by auto

          from goal2 have [simp]: "snd (snd z) = init" using config_n_init3[simplified]   by metis

          from goal2 have [simp]: "length (fst (snd z)) = length init" using config_n_fst_init_length2[simplified] by metis 

          have indexinbounds: "index init x < length init" "index init y < length init"  using a by auto
          from a xny have indnot: "index init x \<noteq> index init y" by auto



          have 1: "index init x < length (fst (snd z))" using xyininit by auto
          have 2: "index init y < length (fst (snd z))" using xyininit by auto
          have 3: "index init x \<noteq> index init y" using xny xyininit by auto

          
          from dinit have dfil: "distinct (Lxy init {x,y})" by(rule Lxy_distinct)
          have Lxy_set: "set (Lxy init {x, y}) = {x,y}" apply(simp add: Lxy_set_filter) using xyininit by fast
          then have xLxy: "x\<in>set (Lxy init {x, y})" by auto
          have Lxy_length: "length (Lxy init {x, y}) = 2" using dfil Lxy_set xny distinct_card by fastforce 
          have 31:  "index (Lxy init {x, y}) x < 2" 
              and  32:  "index (Lxy init {x, y}) y < 2" using Lxy_set xyininit Lxy_length by auto
          have 33: "index (Lxy init {x, y}) x \<noteq> index (Lxy init {x,y}) y"
            using xny xLxy by auto
 
          have a1: "sublist (flip (index init (qs ! n)) (fst (snd z))) {index init x,index init y}
                = flip (index (Lxy init {x,y}) (qs ! n)) (sublist (fst (snd z)) {index init x,index init y})" (is "?A=?B")
          proof (simp only: list_eq_iff_nth_eq)
            case goal1


            thm sublist_project'
            {assume ass: "index init x < index init y"
              then have "index (Lxy init {x,y}) x < index (Lxy init {x,y}) y"
                using Lxy_mono[OF xyininit dinit] before_in_def by (smt a(2))
              with 31 32 have ix: "index (Lxy init {x,y}) x = 0"
                      and iy: "index (Lxy init {x,y}) y = 1" by auto


             have g1: "(sublist (fst (snd z)) {index init x,index init y}) 
                        = [(fst (snd z)) ! index init x, (fst (snd z)) ! index init y]"
                        apply(rule sublist_project')
                          using xyininit apply(simp)
                          using xyininit apply(simp)
                          by fact


            have "sublist (flip (index init (qs ! n)) (fst (snd z))) {index init x,index init y}
                  = [flip (index init (qs ! n)) (fst (snd z))!index init x,
                        flip (index init (qs ! n)) (fst (snd z))!index init y]"
                        apply(rule sublist_project')
                          using xyininit apply(simp)
                          using xyininit apply(simp)
                          by fact
            also have "\<dots> = flip (index (Lxy init {x,y}) (qs ! n)) [(fst (snd z)) ! index init x, (fst (snd z)) ! index init y]" 
              apply(cases "qs!n=x")
                apply(simp add: ix) using flip_other[OF 2 1 3] flip_itself[OF 1] apply(simp)
                using whatisq apply(simp add: iy) using flip_other[OF 1 2 3[symmetric]] flip_itself[OF 2] by(simp)
            finally have "sublist (flip (index init (qs ! n)) (fst (snd z))) {index init x,index init y}
                    = flip (index (Lxy init {x,y}) (qs ! n)) (sublist (fst (snd z)) {index init x,index init y})" 
                    by(simp add: g1)
                          
            }note cas1=this
            have man: "{x,y} = {y,x}" by auto
            {assume "~ index init x < index init y"
              then have ass: "index init y < index init x" using 3 by auto
              then have "index (Lxy init {x,y}) y < index (Lxy init {x,y}) x"
                using Lxy_mono[OF xyininit' dinit] xyininit a(1) man by(simp add: before_in_def)
              with 31 32 have ix: "index (Lxy init {x,y}) x = 1"
                      and iy: "index (Lxy init {x,y}) y = 0" by auto


             have g1: "(sublist (fst (snd z)) {index init y,index init x}) 
                        = [(fst (snd z)) ! index init y, (fst (snd z)) ! index init x]"
                        apply(rule sublist_project')
                          using xyininit apply(simp)
                          using xyininit apply(simp)
                          by fact

            have man2: "{index init x,index init y} = {index init y,index init x}" by auto
            have "sublist (flip (index init (qs ! n)) (fst (snd z))) {index init y,index init x}
                  = [flip (index init (qs ! n)) (fst (snd z))!index init y,
                        flip (index init (qs ! n)) (fst (snd z))!index init x]"
                        apply(rule sublist_project')
                          using xyininit apply(simp)
                          using xyininit apply(simp)
                          by fact
            also have "\<dots> = flip (index (Lxy init {x,y}) (qs ! n)) [(fst (snd z)) ! index init y, (fst (snd z)) ! index init x]" 
              apply(cases "qs!n=x")
                apply(simp add: ix) using flip_other[OF 2 1 3] flip_itself[OF 1] apply(simp)
                using whatisq apply(simp add: iy) using flip_other[OF 1 2 3[symmetric]] flip_itself[OF 2] by(simp)
            finally have "sublist (flip (index init (qs ! n)) (fst (snd z))) {index init y,index init x}
                    = flip (index (Lxy init {x,y}) (qs ! n)) (sublist (fst (snd z)) {index init y,index init x})" 
                    by(simp add: g1)
            then have "sublist (flip (index init (qs ! n)) (fst (snd z))) {index init x,index init y}
                    = flip (index (Lxy init {x,y}) (qs ! n)) (sublist (fst (snd z)) {index init x,index init y})" 
                    using man2 by auto                          
            } note cas2=this

            from cas1 cas2 3 show ?case by metis 
          qed

          thm sublist_project
          have a: "sublist (fst (snd z)) {index init x, index init y} ! (index (Lxy init {x,y}) (qs ! n))
                    = fst (snd z) ! (index init (qs ! n))"
          proof -
            from 31 32  33have ca: "(index (Lxy init {x,y}) x = 0 \<and> index (Lxy init {x,y}) y = 1)
                    \<or> (index (Lxy init {x,y}) x = 1 \<and> index (Lxy init {x,y}) y = 0)" by force
            show ?thesis
            proof (cases "index (Lxy init {x,y}) x = 0")
              case True

              thm dinit

              from True ca have y1: "index (Lxy init {x,y}) y = 1" by auto
              with True have "index (Lxy init {x,y}) x < index (Lxy init {x,y}) y" by auto
              then have xy: "index init x < index init y" using dinit dfil Lxy_mono 
                      using "32" before_in_def Lxy_length xyininit by fastforce 
                  

              have 4: " {index init y, index init x} =  {index init x, index init y}" by auto

              have "sublist (fst (snd z)) {index init x, index init y} ! index (Lxy init {x,y}) x = (fst (snd z)) ! index init x"
                       "sublist (fst (snd z)) {index init x, index init y} ! index (Lxy init {x,y}) y = (fst (snd z)) ! index init y"
                       unfolding True y1 
                          by (simp_all only: sublist_project[OF 1 2 xy])  
              with whatisq show ?thesis by auto
           next
              case False
              with ca have x1: "index (Lxy init {x,y}) x = 1" by auto
              thm dinit
              from dinit have dfil: "distinct (Lxy init {x,y})" by(rule Lxy_distinct)

              from x1 ca have y1: "index (Lxy init {x,y}) y = 0" by auto
              with x1 have "index (Lxy init {x,y}) y < index (Lxy init {x,y}) x" by auto
              then have xy: "index init y < index init x" using dinit dfil Lxy_mono 
                      using "32" before_in_def Lxy_length xyininit by (metis a(2) indnot linorder_neqE_nat not_less0 y1) 
                  

              have 4: " {index init y, index init x} =  {index init x, index init y}" by auto

              thm sublist_project[OF  2 1 xy]

              have "sublist (?b) {index init x, index init y} ! index (Lxy init {x,y}) x = (?b) ! index init x"
                       "sublist (?b) {index init x, index init y} ! index (Lxy init {x,y}) y = (?b) ! index init y"
                       unfolding x1 y1 
                        using 4 sublist_project[OF  2 1 xy]
                          by simp_all  
              with whatisq show ?thesis by auto
           qed
         qed


          have b: "Lxy (mtf2 (length ?s) (qs ! n) ?s) {x, y} 
                =  mtf2 (length (Lxy ?s {x, y})) (qs ! n) (Lxy ?s {x, y})" (is "?A = ?B")
          proof -
            
                thm mtf2_moves_to_front'[simplified]
                have sA: "set ?A = {x,y}" using z xyininit by(simp add: Lxy_set_filter)
                then have xlxymA: "x \<in> set ?A"
                      and ylxymA: "y \<in> set ?A" by auto
                have dA: "distinct ?A" apply(rule Lxy_distinct) by(simp add: dz)
                have lA: "length ?A = 2" using xny sA dA distinct_card by fastforce 
                from lA ylxymA have yindA: "index ?A y < 2" by auto
                from lA xlxymA have xindA: "index ?A x < 2" by auto
                have geA: "{x,y} \<subseteq> set (mtf2 (length ?s) (qs ! n) ?s)" using xyininit z by auto
                have geA': "{y,x} \<subseteq> set (mtf2 (length ?s) (qs ! n) (?s))" using xyininit z by auto
                have man: "{y,x} = {x,y}" by auto

                have sB: "set ?B = {x,y}" using z xyininit by(simp add: Lxy_set_filter)
                then have xlxymB: "x \<in> set ?B"
                  and ylxymB: "y \<in> set ?B" by auto
                have dB: "distinct ?B" apply(simp) apply(rule Lxy_distinct) by(simp add: dz)
                have lB: "length ?B = 2" using xny sB dB distinct_card by fastforce 
                from lB ylxymB have yindB: "index ?B y < 2" by auto
                from lB xlxymB have xindB: "index ?B x < 2" by auto
                
                show ?thesis
                proof (cases "qs!n = x")                
                  case True
                  then have xby: "x < y in (mtf2 (length (?s)) (qs ! n) (?s))"
                    apply(simp)
                          apply(rule mtf2_moves_to_front''[simplified])
                            using z xyininit xny by(simp_all add: dz)
                  then have "x < y in ?A" using Lxy_mono[OF geA] dz by(auto)
                  then have "index ?A x < index ?A y" unfolding before_in_def by auto
                  then have in1: "index ?A x = 0"
                          and in2: "index ?A y = 1"  using yindA by auto
                  have "?A = [?A!0,?A!1]" 
                          apply(simp only: list_eq_iff_nth_eq)
                            apply(auto simp: lA) apply(case_tac i) by(auto)
                  also have "\<dots> = [?A!index ?A x, ?A!index ?A y]" by(simp only: in1 in2)
                  also have "\<dots> = [x,y]" using xlxymA ylxymA  by(simp add: nth_index)    
                  finally have end1: "?A  = [x,y]" .
                  
                  have "x < y in ?B"
                    using True apply(simp)
                          apply(rule mtf2_moves_to_front''[simplified])
                            using z xyininit xny by(simp_all add: Lxy_distinct dz Lxy_set_filter)
                  then have "index ?B x < index ?B y"
                            unfolding before_in_def by auto
                  then have in1: "index ?B x = 0"
                          and in2: "index ?B y = 1"
                            using yindB by auto
  
                  have "?B = [?B!0, ?B!1]" 
                          apply(simp only: list_eq_iff_nth_eq)
                            apply(simp only: lB)
                            apply(auto) apply(case_tac i) by(auto)
                  also have "\<dots> = [?B!index ?B x,  ?B!index ?B y]"
                                 by(simp only: in1 in2)
                  also have "\<dots> = [x,y]" using xlxymB ylxymB  by(simp add: nth_index)    
                  finally have end2: "?B = [x,y]" .
  
                  then show "?A = ?B " using end1 end2 by simp
              next             
                  case False
                  with whatisq have qsy: "qs!n=y" by simp
                  then have xby: "y < x in (mtf2 (length (?s)) (qs ! n) (?s))"
                    apply(simp)
                          apply(rule mtf2_moves_to_front''[simplified])
                            using z xyininit xny by(simp_all add: dz)
                  then have "y < x in ?A" using Lxy_mono[OF geA'] man dz by auto
                  then have "index ?A y < index ?A x" unfolding before_in_def by auto
                  then have in1: "index ?A y = 0"
                          and in2: "index ?A x = 1"  using xindA by auto
                  have "?A = [?A!0,?A!1]" 
                          apply(simp only: list_eq_iff_nth_eq)
                            apply(auto simp: lA) apply(case_tac i) by(auto)
                  also have "\<dots> = [?A!index ?A y, ?A!index ?A x]" by(simp only: in1 in2)
                  also have "\<dots> = [y,x]" using xlxymA ylxymA  by simp    
                  finally have end1: "?A  = [y,x]" .
                  
                  have "y < x in ?B"
                    using qsy apply(simp)
                          apply(rule mtf2_moves_to_front''[simplified])
                            using z xyininit xny by(simp_all add: Lxy_distinct dz Lxy_set_filter)
                  then have "index ?B y < index ?B x"
                            unfolding before_in_def by auto
                  then have in1: "index ?B y = 0"
                          and in2: "index ?B x = 1"
                            using xindB by auto
  
                  have "?B = [?B!0, ?B!1]" 
                          apply(simp only: list_eq_iff_nth_eq)
                            apply(simp only: lB)
                            apply(auto) apply(case_tac i) by(auto)
                  also have "\<dots> = [?B!index ?B y,  ?B!index ?B x]"
                                 by(simp only: in1 in2)
                  also have "\<dots> = [y,x]" using xlxymB ylxymB  by(simp )    
                  finally have end2: "?B = [y,x]" .
  
                  then show "?A = ?B " using end1 end2 by simp
              qed  
           qed 
          
          have a2: " Lxy (step (?s) (qs ! n) (if ?b ! (index init (qs ! n)) then 0 else length (?s), [])) {x, y}
              = step (Lxy (?s) {x, y}) (qs ! n) (if sublist (?b) {index init x, index init y} ! (index (Lxy init {x,y}) (qs ! n)) 
                              then 0 
                              else length (Lxy (?s) {x, y}), [])"
               apply(auto simp add: a step_def) by(simp add: b)
          from a1 a2 show ?case by simp
        qed simp 
        also have "\<dots>=config'' BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x, y} qs (Suc n))"
          using 5 apply(simp add:  nrofnextxy_Suc[OF nqs True] take_Suc_conv_app_nth config'_rand_snoc)  
          apply(subst iH) by(simp add: split_def ) 
        finally show ?thesis .
      next
        case False
        then have qnx: "(qs!n) \<noteq> x" and qny: "(qs!n) \<noteq> y" by auto

        let ?proj="(\<lambda>a. (Lxy (fst a) {x, y}, (sublist (fst (snd a)) {index init x, index init y}, Lxy init {x, y})))"

        note gut=nrofnextxy_Suc2[OF nqs False]                                     
        note iH=Suc(1)[OF nLastxy]
        have "map_pmf ?proj (config'' BIT qs init (Suc n))
             = map_pmf ?proj (config'' (BIT_init, BIT_step) qs init n
                \<bind> (\<lambda>p. BIT_step p (qs ! n) \<bind> (\<lambda>pa. return_pmf (step (fst p) (qs ! n) (fst pa), snd pa)))) "
               using nqs by (simp add: split_def take_Suc_conv_app_nth config'_rand_snoc)
        also have "\<dots> = map_pmf ?proj (config'' (BIT_init, BIT_step) qs init n)" 
            apply(simp add: map_pmf_def bind_assoc_pmf bind_return_pmf BIT_step_def)
            proof (rule bind_pmf_cong)
              case (goal2 z)
              let ?s = "fst z"
              let ?m = "snd (snd z)"
              let ?b = "fst (snd z)"

              from goal2 have sf_init: "?m = init" using config_n_init3 by auto

              from goal2 have ff_len: "length (?b) = length init" using config_n_fst_init_length2 by auto
              
              have ff_ix: "index init x < length (?b)" unfolding ff_len using a(1) by auto
              have ff_iy: "index init y < length (?b)" unfolding ff_len using a(2) by auto
              have ff_q: "index init (qs!n) < length (?b)" unfolding ff_len using qininit by auto
              have iq_ix: "index init (qs!n) \<noteq> index init x" using a(1) qnx by auto
              have iq_iy: "index init (qs!n) \<noteq> index init y" using a(2) qny by auto
              have ix_iy: "index init x \<noteq> index init y" using a(2) xny by auto

              from goal2 have s_set[simp]: "set (?s) = set init" using config_rand_set by force
              have s_xin: "x\<in>set (?s)" using a(1) by simp
              have s_yin: "y\<in>set (?s)" using a(2) by simp
              from goal2 have s_dist: "distinct (?s)" using config_rand_distinct dinit by force
              have s_qin: "qs ! n \<in> set (?s)" using qininit by simp


              have fstfst: "sublist (flip (index ?m (qs ! n)) (?b))
              {index init x, index init y}
                  = sublist (?b) {index init x, index init y}" (is "sublist ?A ?I = sublist ?B ?I")
              proof (cases "index init x < index init y")
                case True
                thm sublist_project'
                have "sublist ?A ?I = [?A!index init x, ?A!index init y]"
                      apply(rule sublist_project')
                        by(simp_all add: ff_ix ff_iy True)
                also have "\<dots> = [?B!index init x, ?B!index init y]"
                  unfolding sf_init using flip_other ff_ix ff_iy ff_q iq_ix iq_iy by auto
                also have "\<dots> = sublist ?B ?I"
                      apply(rule sublist_project'[symmetric])
                        by(simp_all add: ff_ix ff_iy True)
                finally show ?thesis .
              next
                case False
                then have yx: "index init y < index init x" using ix_iy by auto
                have man: "?I =  {index init y, index init x}" by auto
                have "sublist ?A {index init y, index init x}  = [?A!index init y, ?A!index init x]"
                      apply(rule sublist_project')
                        by(simp_all add: ff_ix ff_iy yx)
                also have "\<dots> = [?B!index init y, ?B!index init x]"
                  unfolding sf_init using flip_other ff_ix ff_iy ff_q iq_ix iq_iy by auto
                also have "\<dots> = sublist ?B {index init y, index init x}"
                      apply(rule sublist_project'[symmetric])
                        by(simp_all add: ff_ix ff_iy yx)
                finally show ?thesis by(simp add: man)
              qed


              have snd: "Lxy (step (?s) (qs ! n)
                  (if ?b ! index ?m (qs ! n) then 0 else length (?s),
                   [])) {x, y} = Lxy (?s) {x, y}" (is "Lxy ?A {x,y} = Lxy ?B {x,y}")
              proof (cases "x < y in ?B")
                thm Lxy_project
                case True
                note B=this
                then have A: "x<y in ?A" apply(auto simp add: step_def split_def)
                  apply(rule x_stays_before_y_if_y_not_moved_to_front)
                    by(simp_all add: a s_dist qny[symmetric] qininit)

                have "Lxy ?A {x,y} = [x,y]"
                  apply(rule Lxy_project)
                    by(simp_all add: xny set_step distinct_step A s_dist a xny)
                also have "... = Lxy ?B {x,y}"
                  apply(rule Lxy_project[symmetric])
                    by(simp_all add: xny B s_dist a)
                finally show ?thesis .
              next
                case False
                then have B: "y < x in ?B" using not_before_in[OF s_xin s_yin] xny by simp
                then have A: "y < x in ?A " apply(auto simp add: step_def split_def)
                  apply(rule x_stays_before_y_if_y_not_moved_to_front)
                    by(simp_all add: a s_dist qnx[symmetric] qininit)
                have man: "{x,y} = {y,x}" by auto
                have "Lxy ?A {y,x} = [y,x]"
                  apply(rule Lxy_project)
                    by(simp_all add: xny[symmetric] set_step distinct_step A s_dist a)
                also have "... = Lxy ?B {y,x}"
                  apply(rule Lxy_project[symmetric])
                    by(simp_all add: xny[symmetric] B s_dist a)
                finally show ?thesis using man by auto
              qed
 
              show ?case by(simp add: fstfst snd)
            qed simp
        also have "\<dots> = config'' BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x, y} qs n)"
          using iH by (auto simp: split_def)
        also have "\<dots> = config'' BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x, y} qs (Suc n))"
          by(simp add: gut)
        finally show ?thesis by (simp add: split_def)
      qed 
    qed
    } note strong=this

    thm strong
    
  { 
    fix n::nat
    assume nqs: "n < Lastxy qs {x,y}"
    thm strong[OF nqs]
    have "Pbefore_in x y BIT qs init n = 
        map_pmf (\<lambda>p. x < y in fst p)
            (map_pmf (\<lambda>(l, (w, i)). (Lxy l {x, y}, (sublist w {index init x, index init y}, Lxy init {x, y})))
                  (config'' BIT qs init n))" 
                  unfolding Pbefore_in_def apply(simp add: map_pmf_def bind_return_pmf bind_assoc_pmf split_def)
                  apply(rule bind_pmf_cong)
                    apply(simp)
                    proof -
                      case (goal1 z)
                      let ?s = "fst z"
                      from goal1 have u: "set (?s) = set init" using config_rand[of BIT, simplified] by metis
                      from goal1 have v: "distinct (?s)" using dinit config_rand[of BIT, simplified] by metis
                      have "(x < y in ?s) = (x < y in Lxy (?s) {x, y})"
                        apply(rule Lxy_mono)
                          using u xyininit apply(simp)
                          using v by simp
                      then show ?case by simp
                    qed
     also have "\<dots> = map_pmf (\<lambda>p. x < y in fst p) (config'' BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x, y} qs n))"
        apply(subst strong[OF nqs]) by simp
     also have "\<dots> = Pbefore_in x y BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x,y} qs n)" unfolding Pbefore_in_def by simp
     finally have "Pbefore_in x y BIT qs init n =
        Pbefore_in x y BIT (Lxy qs {x, y}) (Lxy init {x, y}) (nrofnextxy {x,y} qs n)" .      
  
  } note fine=this

  with goal1(4) show ?case by simp
  (* posxy :      index in Lxy \<mapsto> index in qs
     nrofnextxy:  index in qs \<mapsto> index in Lxy
     
  from goal1(4)  have "(posxy qs {x, y} n) < length qs"
    using posxy_in_bounds by metis
  then have img_in_bounds: "(posxy qs {x, y} n) \<le> length qs" by auto
  
  from goal1(4) have bij: "(nrofnextxy {x, y} qs (posxy qs {x, y} n)) = n"
    using nrofnextxy_posxy_id by auto

  from fine[OF img_in_bounds,unfolded bij] show ?case . *)
qed


theorem BIT_pairwise: "pairwise BIT"
apply(rule pairwise_property_lemma')
  apply(rule BIT_pairwise') by(simp_all)





end