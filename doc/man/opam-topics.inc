;; Generated by dune_man

(rule
  (with-stdout-to opam-help.1 (run %{bin:opam} help --help=groff)))

(rule
  (with-stdout-to opam-admin.1 (run %{bin:opam} admin --help=groff)))

(rule
  (with-stdout-to opam-lock.1 (run %{bin:opam} lock --help=groff)))

(rule
  (with-stdout-to opam-clean.1 (run %{bin:opam} clean --help=groff)))

(rule
  (with-stdout-to opam-lint.1 (run %{bin:opam} lint --help=groff)))

(rule
  (with-stdout-to opam-source.1 (run %{bin:opam} source --help=groff)))

(rule
  (with-stdout-to opam-unpin.1 (run %{bin:opam} unpin --help=groff)))

(rule
  (with-stdout-to opam-pin.1 (run %{bin:opam} pin --help=groff)))

(rule
  (with-stdout-to opam-switch.1 (run %{bin:opam} switch --help=groff)))

(rule
  (with-stdout-to opam-remote.1 (run %{bin:opam} remote --help=groff)))

(rule
  (with-stdout-to opam-repository.1 (run %{bin:opam} repository --help=groff)))

(rule
  (with-stdout-to opam-env.1 (run %{bin:opam} env --help=groff)))

(rule
  (with-stdout-to opam-exec.1 (run %{bin:opam} exec --help=groff)))

(rule
  (with-stdout-to opam-var.1 (run %{bin:opam} var --help=groff)))

(rule
  (with-stdout-to opam-config.1 (run %{bin:opam} config --help=groff)))

(rule
  (with-stdout-to opam-upgrade.1 (run %{bin:opam} upgrade --help=groff)))

(rule
  (with-stdout-to opam-update.1 (run %{bin:opam} update --help=groff)))

(rule
  (with-stdout-to opam-reinstall.1 (run %{bin:opam} reinstall --help=groff)))

(rule
  (with-stdout-to opam-uninstall.1 (run %{bin:opam} uninstall --help=groff)))

(rule
  (with-stdout-to opam-remove.1 (run %{bin:opam} remove --help=groff)))

(rule
  (with-stdout-to opam-install.1 (run %{bin:opam} install --help=groff)))

(rule
  (with-stdout-to opam-info.1 (run %{bin:opam} info --help=groff)))

(rule
  (with-stdout-to opam-show.1 (run %{bin:opam} show --help=groff)))

(rule
  (with-stdout-to opam-search.1 (run %{bin:opam} search --help=groff)))

(rule
  (with-stdout-to opam-list.1 (run %{bin:opam} list --help=groff)))

(rule
  (with-stdout-to opam-init.1 (run %{bin:opam} init --help=groff)))

(install
  (section man)
  (package opam)
  (files
    opam-help.1 
    opam-admin.1 
    opam-lock.1 
    opam-clean.1 
    opam-lint.1 
    opam-source.1 
    opam-unpin.1 
    opam-pin.1 
    opam-switch.1 
    opam-remote.1 
    opam-repository.1 
    opam-env.1 
    opam-exec.1 
    opam-var.1 
    opam-config.1 
    opam-upgrade.1 
    opam-update.1 
    opam-reinstall.1 
    opam-uninstall.1 
    opam-remove.1 
    opam-install.1 
    opam-info.1 
    opam-show.1 
    opam-search.1 
    opam-list.1 
    opam-init.1))