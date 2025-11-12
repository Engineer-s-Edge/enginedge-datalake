# Description

<!-- Provide a brief description of your changes -->

## Related Issue

<!-- Link to the issue this PR addresses -->
Fixes #(issue number)

## Type of Change

<!-- Mark the relevant option with an 'x' -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] CI/CD or build configuration change
- [ ] Dependency update

## Testing

<!-- Describe the tests you ran to verify your changes -->

- [ ] Unit tests pass locally
- [ ] Integration tests pass locally
- [ ] Manual testing completed
- [ ] Added new tests for this change

### Test Commands Run

```bash
# Example:
pytest tests/ -v
npm run build
docker compose up -d && pytest tests/test_minio.py
```

## Checklist

<!-- Mark completed items with an 'x' -->

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings or errors
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

## CI/CD Status

<!-- CI will run automatically. Address any failures before requesting review -->

- [ ] All CI checks pass
- [ ] No security vulnerabilities introduced
- [ ] Docker builds successfully (if applicable)

## Screenshots (if applicable)

<!-- Add screenshots to help explain your changes -->

## Performance Impact

<!-- Does this change affect performance? How? -->

## Backward Compatibility

<!-- Does this change break anything? What's the migration path? -->

## Additional Notes

<!-- Any other information reviewers should know -->

## Reviewer Checklist

<!-- For reviewers - don't delete this section -->

- [ ] Code quality is good
- [ ] Tests are adequate
- [ ] Documentation is updated
- [ ] No security concerns
- [ ] Performance is acceptable
