# Helm chart maintenance. `deps` must run before lint/template/diff because
# every chart depends on the local `common` library chart via file://../common.

CHARTS := LiveInvest PracticeInvesting RoboAdvisory WebPortals

# StackValues files that are known to be unpopulated. They fail on purpose;
# fill them in and remove them from this list.
UNPOPULATED := WebPortals/StackValues/dev-values.yaml \
               WebPortals/StackValues/production-values.yaml

.PHONY: help deps lint template clean

help:
	@echo "make deps      resolve the common library chart into each chart"
	@echo "make lint      helm lint every chart against every StackValues file"
	@echo "make template  render every chart x environment, and every overlay"
	@echo "make clean     remove resolved dependencies"

deps:
	@for c in $(CHARTS); do helm dependency update $$c >/dev/null || exit 1; done
	@echo "dependencies resolved"

lint: deps
	@rc=0; \
	for c in $(CHARTS); do \
	  for f in $$c/StackValues/*.yaml; do \
	    case " $(UNPOPULATED) " in *" $$f "*) echo "skip  $$f (unpopulated)"; continue;; esac; \
	    if helm lint $$c -f $$f --quiet >/dev/null 2>&1; then echo "ok    $$f"; \
	    else echo "FAIL  $$f"; helm lint $$c -f $$f --quiet 2>&1 | head -20; rc=1; fi; \
	  done; \
	done; exit $$rc

template: deps
	@rc=0; \
	for c in $(CHARTS); do \
	  for f in $$c/StackValues/*.yaml; do \
	    case " $(UNPOPULATED) " in *" $$f "*) continue;; esac; \
	    env=$$(basename $$f .yaml); \
	    helm template rel $$c -f $$f >/dev/null || { echo "FAIL stack $$f"; rc=1; }; \
	  done; \
	  for d in $$c/ServiceValues/*/; do \
	    [ -d "$$d" ] || continue; \
	    env=$$(basename $$d); \
	    stack=$$(ls $$c/StackValues/$$env-values.yaml $$c/StackValues/$$env.yaml 2>/dev/null | head -1); \
	    [ -n "$$stack" ] || { echo "FAIL no StackValues for $$c/$$env"; rc=1; continue; }; \
	    for f in $$d*.yaml; do \
	      helm template rel $$c -f $$stack -f $$f >/dev/null || { echo "FAIL overlay $$f"; rc=1; }; \
	    done; \
	  done; \
	done; \
	[ $$rc -eq 0 ] && echo "all charts and overlays render"; exit $$rc

clean:
	@rm -rf $(addsuffix /charts,$(CHARTS)) $(addsuffix /Chart.lock,$(CHARTS))
	@echo "cleaned"
