- For HTML / ERB changes, validate:
  - file easier or harder to read
  - same feature spread across more files
  - new partial/helper really justified

- Reject:
  - micro-partials
  - deep partial nesting
  - partial for a single local use case
  - helper without repeated logic
  - extra wrapper div/class without styling or behavior need
  - splitting one local UI block across multiple files
  - structure harder to understand than before

- Partial only if:
  - repeated markup exists
  - same UI appears in multiple places
  - block is large enough to hurt readability
  - block is likely to evolve independently

- Prefer:
  - inline ERB for short local markup
  - one readable file over many small files
  - existing CSS classes
  - minimal HTML diff